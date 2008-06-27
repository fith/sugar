require 'paginates'

class Discussion < ActiveRecord::Base

    UNSAFE_ATTRIBUTES = :id, :sticky, :user_id, :last_poster_id, :posts_count, :created_at, :last_post_at

    belongs_to :poster, :class_name => 'User', :counter_cache => true
    belongs_to :last_poster, :class_name => 'User'
    belongs_to :category
    has_many   :posts, :order => ['created_at ASC']

    validates_presence_of :category_id, :title
    validates_presence_of :body, :on => :create
    
    # Virtual attribute for the body of the first post. 
    # Makes forms a bit easier, no nested models.
    attr_accessor :body
    
    # Update the first post if @body has been changed
    after_update do |discussion|
        if discussion.body && !discussion.body.empty?
            discussion.posts.first.update_attribute(:body, discussion.body)
        end
    end
    
    # Class methods
    class << self

        # Finds paginated discussions, sorted by activity, with the sticky ones on top.
        # The collection is extended with the Paginates module, which provides pagination info.
        # Takes the following options: 
        #     :page     - Page number, starting on 1 (default: first page)
        #     :limit    - Number of posts per page (default: 20)
        #     :category - Only get discussions in category
        def find_paginated(options)
            discussions_count = (options[:category]) ? options[:category].discussions.count : Discussion.count
            conditions        = (options[:category]) ? ['category_id = ?', options[:category].id] : nil

            # Math is awesome
            limit = options[:limit] || 20
            num_pages = (discussions_count.to_f/limit).ceil
            page  = (options[:page] || 1).to_i
            page = 1 if page < 1
            page = num_pages if page > num_pages
            offset = limit * (page - 1)

            # Grab the discussions
            discussions = self.find(
                :all, 
                :conditions => conditions, 
                :limit      => limit, 
                :offset     => offset, 
                :order      => 'sticky DESC, last_post_at DESC',
                :include    => [:poster, :last_poster, :category]
            )

            # Inject the pagination methods on the collection
            class << discussions; include Paginates; end
            discussions.setup_pagination(num_pages, page, discussions_count, offset)

            return discussions
        end

        # Deletes attributes which normal users shouldn't be able to touch from a param hash
    	def safe_attributes(params)
    	    safe_params = params.dup
    	    UNSAFE_ATTRIBUTES.each do |r|
    	        safe_params.delete(r)
            end
            return safe_params
        end

    end
    
    # Creates the first post. This should probably be called from an after_create filter,
    # right now it's run manually from the controller.
    def create_first_post!
        self.posts.create(:user => self.poster, :body => self.body)
    end
    
    # Does this discussion have any labels?
    def labels?
        (self.closed? || self.sticky? || self.nsfw?) ? true : false
    end
    
    # Returns an array of labels (for use in the thread title)
    def labels
        labels = []
        labels << "Sticky" if self.sticky?
        labels << "Closed" if self.closed?
        labels << "NSFW" if self.nsfw?
        return labels
    end
    
    # Is this discussion editable by the given user?
    def editable_by?(user)
        (user && (user.admin? || user == self.poster)) ? true : false
    end

    # Humanized ID for URLs
    def to_param
        "#{self.id}-" + self.title.downcase.gsub(/[^\w\d]+/,'_')
    end
end
