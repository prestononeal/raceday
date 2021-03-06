class Racer
  include ActiveModel::Model

  attr_accessor :id, :number, :first_name, :last_name, :gender, :group, :secs

  # Initialize from both a Mongo and a Web hash
  def initialize(params={})
    Rails.logger.debug "instantiating Racer (#{params})"
    # switch between both external and internal views of id
    @id = params[:_id].nil? ? params[:id] : params[:_id].to_s
    @number = params[:number]
    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @gender = params[:gender]
    @group = params[:group]
    @secs = params[:secs]
  end

  # Get a mongo client to communicate with the database (configured in config/mongoid.yml)
  def self.mongo_client
    Mongoid::Clients.default
  end

  # Convenience method for accessing the "racers" collection
  def self.collection
    self.mongo_client['racers']
  end

  # Convenience method for returning a collection of documents as hashes
  #   * prototype - query for value equality
  #   * sort - hash expressing multi-term sort order
  #   * offset - document to start results
  #   * limit - number of documents to include
  def self.all(prototype={}, sort={:number=>1}, skip=0, limit=nil)
    # map internal :population term to :pop document term
    tmp = {}  # hash needs to stay in stable order provided
    sort.each {|k,v|
      k = k.to_sym
      tmp[k] = v  if [:number, :first_name, :last_name, :gender, :group, :secs].include?(k)
    }
    sort=tmp

    # convert to keys and then eliminate any properties not of interest
    prototype=prototype.symbolize_keys.slice(:number, :first_name, :last_name, :gender, :group, :secs) if !prototype.nil?

    Rails.logger.debug "getting all racers, prototype=#{prototype}, sort=#{sort}, skip=#{skip}, limit=#{limit}"

    result = collection.find(prototype).sort(sort).skip(skip)
    result = result.limit(limit) if !limit.nil?
    return result
  end

  # Locate a specific document. Use initializatio(hash) on the result to get in class instance form
  def self.find id
    Rails.logger.debug "getting racer #{id}"
    result = collection.find(:_id=>BSON::ObjectId.from_string(id)).first
    return result.nil? ? nil : Racer.new(result)
  end

  def persisted?
    # tell Rails if this object has been saved yet
    !@id.nil?
  end

  def created_at
    nil
  end

  def updated_at
    nil
  end

  # Save the state of the current instance in a DB document and store its id
  def save
    Rails.logger.debug "saving racer #{self}"
    result = self.class.collection.insert_one(id:@id, number:@number, first_name:@first_name,
      last_name:@last_name, gender:@gender, group:@group, secs:@secs)
    @id = result.inserted_id.to_s
  end

  # Update the DB document with the given params and store them in the current instance
  def update params
    Rails.logger.debug "updating racer #{self} with #{params}"
    @number = params[:number].to_i
    @first_name = params[:first_name]
    @last_name = params[:last_name]
    @gender = params[:gender]
    @group = params[:group]
    @secs = params[:secs].to_i
    params.slice!(:number, :first_name, :last_name, :gender, :group, :secs)
    self.class.collection.find(_id:BSON::ObjectId.from_string(@id)).update_one(params)
  end

  # Remove the DB document with the current number
  def destroy
    Rails.logger.debug "destroying racer #{@number} from the DB"
    self.class.collection.find(_id:BSON::ObjectId.from_string(@id)).delete_one
  end

  # Implements the will_paginate method
  #   * params - a hash containing:
  #     * page - current page, defaults to 1
  #     * per_page - how many documents per page, default of 30
  def self.paginate params
    Rails.logger.debug "paginate #{params}"
    page = (params[:page] ||= 1).to_i
    limit = (params[:per_page] ||= 30).to_i
    skip = (page - 1) * limit
    sort = params[:sort] ||= {}

    racers = []
    all(params, sort, skip, limit).each do |doc|
      racers << Racer.new(doc)
    end

    # get a count of all documents in the collection
    total = all(params, sort, 0, 1).count

    WillPaginate::Collection.create(page, limit, total) do |pager|
      pager.replace(racers)
    end
  end
end