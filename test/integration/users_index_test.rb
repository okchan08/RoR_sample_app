require 'test_helper'

class UsersIndexTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
    @admin = users(:michael)
    @non_admin = users(:archer)
    @not_activated = users(:not_activated)
  end

  test "index including pagination" do
    log_in_as(@user)
    get users_path
    assert_template 'users/index'
    assert_select 'div.pagination', count: 2
    User.where(activated: true).paginate(page: 1).each do |user|
      assert_select 'a[href=?]', user_path(user), text: user.name
    end
  end

  test "index for normal user not including non-activated user" do
    log_in_as(@user)
    get users_path
    assert_template 'users/index'
    assert_select "a[href=?]", user_path(@not_activated), count: 0
    get user_path(@not_activated)
    assert_redirected_to root_url
  end

  test "index for admin including pagination and delete links" do
    log_in_as(@admin)
    get users_path
    assert_template 'users/index'
    assert_select 'div.pagination', count: 2
    first_page_of_users = User.where(activated: true).paginate(page: 1)
    first_page_of_users.each do |user|
      assert_select 'a[href=?]', user_path(user), text: user.name
      unless user == @admin
        assert_select 'a[href=?]', user_path(user), text: 'delete'
      end
    end
    assert_difference 'User.count', -1 do
      delete user_path(@non_admin)
    end
    assert_redirected_to users_url
    follow_redirect!
    assert_select 'div.alert-success'
  end
end
