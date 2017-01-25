class AdminController < ApplicationController

  before_action :authorize_as_admin, :except => [:review_commenting_requests]

  def authorize_as_admin
    unless @user.is_admin
      session[:original_uri] = request.request_uri
      flash[:notice]         = 'Please log in as an administrator.'
      redirect_to new_session_path
    end
  end

  def index
  end

  def dashboard
    @user_count               = Person.count
    @new_user_count           = Person.where('created_at > ?', Time.now - 1.month).count
    @recent_reports           = Report.where('created_at > ?', Time.now - 1.month)
    @active_user_count        = @recent_reports.collect { |r| r.person_id }.uniq.count
    @report_count             = Report.count
    @requester_count          = Requester.count
    @recent_report_count      = @recent_reports.count
    authors                   = @recent_reports.map { |r| { id: r.person_id, name: r.person.display_name || r.person.email } }
    @author_count             = authors.uniq.count
    @authors_with_counts      = authors.group_by { |a| [a[:id], a[:name]] }.map { |k, v| [k, v.length] }.sort_by { |a| a[1] }.reverse
    @recent_flags             = LegacyFlag.where('created_at > ?', Time.now - 1.month)
    @recently_flagged_reports = @recent_flags.collect{|f| f.report_id}
    @recent_flaggers          = @recent_flags.collect{|f| f.person_id}
    top_flaggers              = {}
    @recent_flaggers.each do |pid|
      if top_flaggers[pid].nil?
        top_flaggers[pid] = 1
      else
        top_flaggers[pid] += 1
      end
    end
    @ordered_flaggers = top_flaggers.sort_by{|k, v| v}.reverse
  end

  def reviewers
    reviewers = {}
    Review.all.each { |r|
      pid = r.person_id
      if reviewers[pid].nil?
        p = Person.find(pid)
        reviewers[pid] = {:public_email => p.public_email,
                          :acct_date => p.created_at.strftime("%b %d %Y"),
                          :can_comment => p.can_comment.to_s,
                          :review_count => 0}
      end
      reviewers[pid][:review_count] += 1
    }
    @review_counts = []
    reviewers.each_pair{|pid, info|
      @review_counts << {:person_id => pid,
                         :review_count => info[:review_count],
                         :public_email => info[:public_email],
                         :acct_date => info[:acct_date],
                         :can_comment => info[:can_comment]}
    }
    @review_counts = @review_counts.sort_by{|e| e[:review_count]}.reverse
  end

  def commenters
    @commenters_and_comments = {}
    LegacyComment.all.each { |c|
      if c.person_id
        if @commenters_and_comments[c.person_id].nil?
          p = Person.find(c.person_id)
          @commenters_and_comments[c.person_id] = {:public_email => p.public_email, :mod_display_name => p.mod_display_name, :acct_date => p.created_at.strftime("%b %d %Y"), :can_comment => p.can_comment.to_s, :comments => []}
        end
        @commenters_and_comments[c.person_id][:comments] << {:comment_id => c.id, :date => c.created_at.strftime("%b %d %Y %H:%M"), :body => c.body}
      end
    }

    @comment_counts = []
    @commenters_and_comments.each_pair{|person_id, info|
      @comment_counts << {:person_id => person_id, :comment_count => info[:comments].count, :last_comment_date => info[:comments].last[:date], :acct_date => info[:acct_date], :can_comment => info[:can_comment]}
    }
    @comment_counts = @comment_counts.sort_by{|e| e[:comment_count]}
  end

  def enable_commenting
    Person.find(params[:id]).update_attributes(:can_comment => true)
    render :text => "Enabled commenting for user #{params[:id]}."
  end

  def enable_commenting_and_send_email
    person = Person.find(params[:id])
    person.update_attributes(:can_comment => true)
    AdminMailer::deliver_enabled(person)
    render :text => "Enabled commenting for user #{params[:id]}."
  end

  def decline_commenting_request
    person = Person.find(params[:id])
    person.update_attributes(:commenting_requested => nil, :commenting_requested_at => nil)
    render :text => "Declined commenting request for user #{params[:id]}."
  end

  def decline_commenting_request_and_send_email
    person = Person.find(params[:id])
    person.update_attributes(:commenting_requested => nil, :commenting_requested_at => nil)
    AdminMailer::deliver_declined(person)
    render :text => "Declined commenting request for user #{params[:id]}. Email sent."
  end

  def approve_commenting_requests
    ids = params[:ids].split(",")
    ids.each{|i| Person.find(i).update_attributes(:can_comment => true)}
    render :text => "Approved commenting requests for users #{ids.join(", ")}."
  end

  def decline_commenting_requests
    ids = params[:ids].split(",")
    ids.each{|i| Person.find(i).update_attributes(:commenting_requested => nil, :commenting_requested_at => nil)}
    render :text => "Declined commenting requests for users #{ids.join(", ")}."
  end

  def disable_commenting
    Person.find(params[:id]).update_attributes(:can_comment => false)
    render :text => "Disabled commenting for user #{params[:id]}."
  end

  def commenting_requests
    @people = Person.find_all_by_can_comment_and_commenting_requested_and_commenting_request_ignored(nil, true, nil).sort_by{|p| p.commenting_requested_at}
    @all_emails = @people.collect{|p| p.email}
    @all_ids = @people.collect{|p| p.id}
  end

  def likely_commenting_requests
    @people = Person.find_all_by_can_comment_and_commenting_requested_and_commenting_request_ignored(nil, true, nil).select{|p| p.reports.count >= 5}.sort_by{|p| p.commenting_requested_at}
    @all_emails = @people.collect{|p| p.email}
    @all_ids = @people.collect{|p| p.id}
    render :action => "commenting_requests"
  end

  def unlikely_commenting_requests
    @people = Person.find_all_by_can_comment_and_commenting_requested_and_commenting_request_ignored(nil, true, nil).select{|p| p.reports.count < 5}.sort_by{|p| p.commenting_requested_at}
    @all_emails = @people.collect{|p| p.email}
    @all_ids = @people.collect{|p| p.id}
  end

  def zero_rev_commenting_requests
    @people = Person.find_all_by_can_comment_and_commenting_requested_and_commenting_request_ignored(nil, true, nil).select{|p| p.reports.count < 1}.sort_by{|p| p.commenting_requested_at}
    @all_emails = @people.collect{|p| p.email}
    @all_ids = @people.collect{|p| p.id}
  end

  def ignore_commenting_request_quietly
    Person.find(params[:id]).update_attributes(:commenting_request_ignored => true)
    render :text => "Ignored commenting request from user #{params[:id]}."
  end

  def enabled_commenters
    @commenters = Person.find_all_by_can_comment(true).sort_by{|p| p.comments.count}.reverse
  end

  def review_commenting_requests
    likely = Person.find_all_by_can_comment_and_commenting_requested_and_commenting_request_ignored(nil, true, nil).select{|p| p.reports.count >= 5}
    out = "Enabled commenting for:\n"
    likely.each{|person|
      person.update_attributes(:can_comment => true)
      AdminMailer::deliver_enabled(person)
        out += "#{person.id.to_s}    #{person.public_email}\n"
    }
    out += "\n\n"
    unlikely = Person.find_all_by_can_comment_and_commenting_requested_and_commenting_request_ignored(nil, true, nil).select{|p| p.reports.count < 5}
    unlikely.each{|person|
      person.update_attributes(:commenting_requested => nil, :commenting_requested_at => nil)
      AdminMailer::deliver_declined(person)
    }
    out += "Declined commenting for " + unlikely.map{|p| p.id}.join(", ")
    AdminMailer::deliver_report(out)
  end

  def duplicated_requesters
    ids = Requester.all.map{|r| r.amzn_requester_id}.delete_if{|i| i.blank?}
    hash = ids.group_by{|i| i}  # slow
    duplicates = hash.select{|k, v| v.size > 1}.map(&:first)
    render :text => duplicates.join(", ")
  end

  def login_as
    session[:person_id] = params[:id]
    redirect_to :controller => "main", :action => "index"
  end

end
