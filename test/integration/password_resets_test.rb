require 'test_helper'

class PasswordResetsTest < ActionDispatch::IntegrationTest
  def setup
    ActionMailer::Base.deliveries.clear
    @user = users(:michael)
  end

  test "password resets" do
    get new_password_reset_path
    assert_template 'password_resets/new'

    post password_resets_path, params: { password_reset: { email: "" } }
    assert_not flash.empty?
    assert_template 'password_resets/new'

    post password_resets_path, params: { password_reset: { email: @user.email } }
    assert_not_equal @user.password_reset_digest, @user.reload.password_reset_digest
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_not flash.empty?
    assert_redirected_to root_url

    user = assigns(:user)

    # with wrong email
    get edit_password_reset_path(user.password_reset_token, email: "")
    assert_redirected_to root_url

    # with non-activated user
    user.toggle!(:activated)
    get edit_password_reset_path(user.password_reset_token, email: user.email)
    assert_redirected_to root_url

    # with wrong token
    user.toggle!(:activated)
    get edit_password_reset_path('wrong token', email: user.email)
    assert_redirected_to root_url

    # with correct token and email
    get edit_password_reset_path(user.password_reset_token, email: user.email)
    assert_template 'password_resets/edit'
    assert_select "input[name=email][type=hidden][value=?]", user.email

    # patch wrong password
    patch password_reset_path(user.password_reset_token),
      params: { email: user.email ,
                user: { password: "hogehoge",
                        password_confirmation: "ahoaho" } }
    assert_template 'password_resets/edit'
    assert_select 'div#error_explanation'


    # patch wrong password
    patch password_reset_path(user.password_reset_token),
      params: { email: user.email ,
                user: { password: "",
                        password_confirmation: "" } }
    assert_select 'div#error_explanation'

    # patch correct new password
    patch password_reset_path(user.password_reset_token),
      params: { email: user.email ,
                user: { password: "newpass",
                        password_confirmation: "newpass" } }
    assert_not is_logged_in?
    assert_redirected_to root_url
    assert_nil @user.reload.password_reset_digest
  end

  test "expired token" do
    get new_password_reset_path
    post password_resets_path,
      params: { password_reset: { email: @user.email } }

    @user = assigns(:user)
    @user.update_attribute(:password_reset_sent_at, 3.hours.ago)
    patch password_reset_path(@user.password_reset_token),
      params: { email: @user.email ,
                user: { password: "newpass",
                        password_confirmation: "newpass" } }
    assert_response :redirect
    follow_redirect!
    assert_match /expired/i, response.body
  end
end
