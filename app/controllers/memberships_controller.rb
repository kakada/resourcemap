class MembershipsController < ApplicationController
  before_filter :authenticate_api_user!
  before_filter :authenticate_collection_admin!, :only => [:create, :destroy, :set_layer_access, :set_admin, :unset_admin, :index]

  def collections_i_admin
    render_json current_user.collections_i_admin(params)
  end

  def index
    memberships = collection.memberships.includes([:read_sites_permission, :write_sites_permission, :name_permission, :location_permission, :layer_memberships])
    anonymous = Membership::Anonymous.new collection, current_user
    render_json({members: memberships, anonymous: anonymous})
  end

  def create
    user = User.find_by_email params[:email]
    if user && !user.memberships.where(:collection_id => collection.id).exists?
      membership = collection.memberships.new user: user
      membership.activity_user = current_user
      membership.save!
      render_json({status: :added, user_id: user.id, user_display_name: user.display_name})
    else
      render_json({status: :not_added})
    end
  end

  def invitable
    users = User.invitable_to_collection(params[:term], collection.memberships.value_of(:user_id))
    render_json users.pluck(:email)
  end

  def search
    users = User.
      where('email LIKE ?', "#{params[:term]}%").
      where("id in (?)", collection.memberships.value_of(:user_id)).
      order('email')
    render_json users.pluck(:email)
  end

  def destroy
    membership = collection.memberships.find_by_user_id params[:id]
    if membership.user_id != current_user.id
      membership.activity_user = current_user
      membership.destroy
    end
    redirect_to collection_members_path(collection)
  end

  def set_access
    generic_set_access {|membership| membership.set_access params}
  end

  def set_layer_access
    generic_set_access {|membership| membership.set_layer_access params}
  end

  def generic_set_access
    membership = collection.memberships.find_by_user_id params[:id]
    membership.activity_user = current_user
    yield membership
    render_json :ok
  end

  def set_access_anonymous_user
    anonymous_membership = Membership::Anonymous.new collection, current_user
    anonymous_membership.activity_user = current_user
    anonymous_membership.set_access params[:object], params[:new_action]
    render_json :ok
  end

  def set_layer_access_anonymous_user
    anonymous_membership = Membership::Anonymous.new collection, current_user
    anonymous_membership.activity_user = current_user
    anonymous_membership.set_layer_access params[:layer_id], params[:verb], params[:access]
    render_json :ok
  end

  def set_admin
    change_admin_flag true
  end

  def unset_admin
    change_admin_flag false
  end

  private

  def change_admin_flag(new_value)
    user_id = params[:id]
    membership = collection.memberships.find_by_user_id user_id
    user = collection.users.find user_id
    membership.admin = new_value
    membership.save!

    Activity.create! item_type: 'admin_permission', action: 'changed', collection_id: collection.id, user_id: current_user.id,
    'data' => {'value' => new_value, 'user' => user.email}
    render_json :ok
  end
end
