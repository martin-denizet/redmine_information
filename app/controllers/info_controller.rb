require 'rails/info'

class InfoController < ApplicationController
  unloadable
  
  before_filter :require_login

  helper :info
  include InfoHelper
  helper :graphviz
  include GraphvizHelper

  def permissions
    @roles = Role.find(:all, :order => 'builtin, position')
    @permissions = Redmine::AccessControl.permissions.select { |p| !p.public? }
  end


  def workflows
    @workflow_counts = Workflow.count_by_tracker_and_role
    @workflow_all_ng_roles = find_all_ng_roles(@workflow_counts)

    @roles = Role.find(:all, :order => 'builtin, position')
    @role = Role.find_by_id(params[:role_id])

    @trackers = Tracker.find(:all, :order => 'position')
    @tracker = Tracker.find_by_id(params[:tracker_id])    
    
    if @tracker && @tracker.issue_statuses.any?
      @statuses = @tracker.issue_statuses
    end
    @statuses ||= IssueStatus.find(:all, :order => 'position')

    if (@tracker && @role && @statuses.any?)
      if (workflow_has_author_assignee)
        workflows = Workflow.all(:conditions => {:role_id => @role.id, :tracker_id => @tracker.id})
        @workflows = {}
        @workflows['always'] = workflows.select {|w| !w.author && !w.assignee}
        @workflows['author'] = workflows.select {|w| w.author}
        @workflows['assignee'] = workflows.select {|w| w.assignee}
      end
    end
      
  end


  def settings
    # Mail Notification
    @notifiables = []
    Redmine::Notifiable.all.each {|notifiable|
      if notifiable.parent.present?
        next	if (Setting.notified_events.include?(notifiable.parent))
      end
      @notifiables << notifiable
    }
    @deliveries = ActionMailer::Base.perform_deliveries

    # Repository
    @commit_fix_status = IssueStatus.find_by_id(Setting[:commit_fix_status_id])
    unless (@commit_fix_status)
      @commit_fix_status = l(:label_no_change_option)
    end
    @commit_fix_done_ratio = Setting[:commit_fix_done_ratio]
    if (!@commit_fix_done_ratio or @commit_fix_done_ratio.empty?)
      @commit_fix_done_ratio = l(:label_no_change_option)
    end

    @commit_logtime_enabled = Setting[:commit_logtime_enabled]
    if (@commit_logtime_enabled)
      @commit_logtime_enabled = (0 < @commit_logtime_enabled.to_i)
    end
    @commit_logtime_activity_name = l(:label_default)
    if (@commit_logtime_enabled)
      aid = Setting[:commit_logtime_activity_id]
      if (aid and 0 < aid.to_i)
        activity = TimeEntryActivity.find_by_id(aid)
        @commit_logtime_activity_name = activity.name	if (activity)
      end
    end

  end
  

  def plugins
    @plugins = Redmine::Plugin.all
  end


  def show
    @icat = params[:id]
    case @icat
    when 'permissions'; permissions;
    when 'workflows'; workflows;
    when 'settings'; settings;
    when 'plugins'; plugins;
    when 'version'
      @db_adapter_name = ActiveRecord::Base.connection.adapter_name 
    end
  end

  private
  def find_all_ng_roles(workflow_counts)
    roles_map = {}
    workflow_counts.each do |tracker, roles|
      roles.each do |role, count|
        roles_map[role] = 0	unless roles_map[role]
        roles_map[role] += count
      end
    end
    all_ng_roles = []
    roles_map.each {|role, count|
      all_ng_roles << role	if (count == 0)
    }
    return all_ng_roles
  end
  
end
