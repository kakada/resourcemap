module CollectionTire
  extend ActiveSupport::Concern

  included do
    after_create :create_index
    after_destroy :destroy_index
  end

  def create_index
    index.create
  end

  def destroy_index
    index.delete
  end

  def index
    self.class.index(id)
  end

  def index_name
    self.class.index_name(id)
  end

  module ClassMethods
    def index_name(id)
      "collection_#{id}"
    end

    def index(id)
      Tire::Index.new index_name(id)
    end
  end
end
