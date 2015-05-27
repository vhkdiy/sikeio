class EnrollmentsController < ApplicationController


  def new
    if !course
      render_404
    end
    if params[:successed] == "true"
      @success_info = true
    end
  end

  def create
    if params[:email].blank?
      flash[:error] = "请输入你邮箱"
      redirect_to  new_enrollment_path(course_id: course.permalink)
      return
    end

    user = User.find_or_initialize_by(email: params[:email])
    if !user.save
      flash[:error] = user.errors.values.flatten.to_s
      redirect_to  new_enrollment_path(course_id: course.permalink)
      return
    end

    @enrollment = Enrollment.find_or_initialize_by user_id: user.id, course_id: course.id
    # already enrolled
    if !enrollment.new_record?
      redirect_to  new_enrollment_path(course_id: course.permalink, successed: true)
      return
    end

    # create new enrollment
    if !enrollment.save
      flash[:error] = enrollment.errors.values.flatten.to_s
      redirect_to  new_enrollment_path(course_id: course.permalink)
      return
    else
      UserMailer.welcome(enrollment).deliver_later
      redirect_to  new_enrollment_path(course_id: course.permalink, successed: true)
    end
  end

  def enroll
    @course_invite = CourseInvite.find_by(token: params[:id])
    if !@course_invite
      render_404
    end

    if current_user
      temp_enrollment = Enrollment.find_or_create_by! user_id: current_user.id, course_id: @course_invite.course_id

      if temp_enrollment.activated?
        redirect_to course_path(temp_enrollment.course)
        return
      end

      @course = @course_invite.course
      @user = current_user
      @enrollment = temp_enrollment
    else
      @enrollment = Enrollment.new course_id: @course_invite.course_id
      @course = @course_invite.course
    end
    render 'invite'
  end

  def invite
    if current_user && enrollment.user != current_user
      enrollment.update_attribute :user, current_user
    end

    if enrollment.activated?
      redirect_to course_path(enrollment.course)
      return
    end

    @course = enrollment.course
    @user = enrollment.user
  end

  def update
    user = enrollment.user
    if user.name.blank?
      name = params[:user][:name]
      if name.present?
        user.update_attribute :name, name
      else
        flash[:error] = "请输入你的姓名"
      end
    end

    enrollment.update_attribute :personal_info, params.require(:personal_info).permit(:blog_url, :occupation, :gender)

    if !user_info_completed?
      redirect_to_invite
      return
    end

    if enrollment.course.free
      activate_course
      return
    end

    redirect_to pay_enrollment_path(@enrollment)
  end

  def pay
    if !user_info_completed?
      redirect_to_invite
      return
    end

    if enrollment.activated
      redirect_to course_path(@enrollment.course)
      return
    end

    @course = @enrollment.course
  end

  # POST
  def finish
    enrollment.buddy_name = params[:buddy_name]
    enrollment.save
    activate_course
  end


  private

  class InvalidEnrollmentTokenError < RuntimeError ; end
  class InvalidPersonalInfoError < RuntimeError ; end

  def activate_course
    enrollment.activate!
    login_as enrollment.user
    redirect_to course_path(enrollment.course)
  end

  def user_info_completed?
    enrollment.user.has_binded_github && (!enrollment.personal_info["occupation"].blank?) && (!enrollment.personal_info["gender"].blank?)
  end

  def redirect_to_invite
    redirect_to invite_enrollment_path(@enrollment)
  end

  def course
    @course ||= Course.by_param!(params[:course_id])
  end

  def enrollment
    return @enrollment if defined?(@enrollment)
    @enrollment = Enrollment.find_by(token: params[:id])
    if @enrollment.nil? || (params[:token] && @enrollment.token != params[:token])
      raise InvalidEnrollmentTokenError
    else
      @enrollment
    end
  end

end
