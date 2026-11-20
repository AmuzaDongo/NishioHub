Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'me/mentor-application', to: 'mentor_applications#show'
      patch 'me/mentor-application', to: 'mentor_applications#update'
      post 'me/mentor-application/documents/:kind', to: 'mentor_applications#upload'
      get 'me/mentor-application/documents/:kind', to: 'mentor_applications#document'
      delete 'me/mentor-application/documents/:kind', to: 'mentor_applications#remove_document'
      post 'me/mentor-application/submit', to: 'mentor_applications#submit'
      get 'admin/mentor-applications', to: 'admin_mentor_applications#index'
      get 'admin/mentor-applications/:id', to: 'admin_mentor_applications#show'
      get 'admin/mentor-applications/:id/documents/:kind', to: 'admin_mentor_applications#document'
      post 'admin/mentor-applications/:id/review', to: 'admin_mentor_applications#review'
      get 'platform/events/discover', to: 'public_events#index'
      get 'platform/events/discover/:id', to: 'public_events#show'
      get 'platform/events/discover/:id/calendar', to: 'public_events#calendar'
      get 'platform/about', to: 'public_home#about'
      get 'platform/home', to: 'public_home#show'
      get 'platform/catalog', to: 'public_home#catalog'
      get 'platform/learning-resources/:id/comments', to: 'resource_comments#index'
      get 'learning/resources/:id/comments/mine', to: 'resource_comments#mine'
      post 'learning/resources/:id/comments', to: 'resource_comments#create'
      delete 'learning/resources/:id/comments/:comment_id', to: 'resource_comments#destroy'
      get 'admin/resources/:id/contents/:content_id/file', to: 'admin_resource_details#supporting_file'
      get 'admin/resources/:id/comments', to: 'resource_comments#moderation'
      patch 'admin/resources/:id/comments/:comment_id', to: 'resource_comments#review'
      get 'learning/resources/:id/contents/:content_id/file', to: 'platform_resources#supporting_file'
      get 'platform/learning-resources', to: 'public_learning_resources#index'
      get 'platform/learning-resources/:id', to: 'public_learning_resources#show'
      get 'platform/learning-resources/:id/thumbnail', to: 'public_learning_resources#thumbnail'
      get 'me/resource-bookmarks', to: 'public_learning_resources#bookmarks'
      put 'me/resource-bookmarks/:id', to: 'public_learning_resources#save_bookmark'
      delete 'me/resource-bookmarks/:id', to: 'public_learning_resources#remove_bookmark'
      get 'platform/programs', to: 'public_programs#index'
      get 'platform/programs/:id', to: 'public_programs#show'
      post 'platform/programs/:id/inquiries', to: 'public_inquiries#create_program_request'
      get 'platform/programs/:id/banner', to: 'program_banners#show'
      post 'platform/partnership-requests', to: 'public_inquiries#create_partnership_request'
      post 'platform/inquiries', to: 'public_inquiries#create'
      post 'platform/event-hosting-requests', to: 'public_inquiries#create_event_request'
      get 'me/event-hosting-requests', to: 'public_inquiries#my_requests'
      patch 'me/event-hosting-requests/:id', to: 'public_inquiries#resubmit'
      post 'admin/inquiries/:id/decision', to: 'public_inquiries#decision'
      get 'admin/inquiries', to: 'public_inquiries#index'
      patch 'admin/inquiries/:id', to: 'public_inquiries#update'
      get 'platform/config', to: 'system_settings#public_config'
      get 'platform/events', to: 'system_settings#public_events'
      get 'admin/integrations', to: 'admin_integrations#index'
      get 'admin/integrations/logs', to: 'admin_integrations#logs'
      patch 'admin/integrations/:key', to: 'admin_integrations#update'
      post 'admin/integrations/:key/status', to: 'admin_integrations#change'
      post 'admin/integrations/:key/check', to: 'admin_integrations#check'
      delete 'admin/integrations/:key', to: 'admin_integrations#disconnect'
      get 'admin/dashboard', to: 'admin_dashboard#show'
      get 'admin/dashboard/search', to: 'admin_dashboard#search'
      get 'admin/dashboard/health', to: 'admin_dashboard#health'
      get 'admin/dashboard/records', to: 'admin_dashboard#records'
      get 'admin/dashboard/options', to: 'admin_dashboard#options'
      post 'admin/dashboard/programs', to: 'admin_dashboard#create_program'
      patch 'admin/dashboard/programs/:id', to: 'admin_dashboard#update_program'
      get 'admin/dashboard/programs/:id/members', to: 'admin_dashboard#members'
      post 'admin/dashboard/programs/:id/members', to: 'admin_dashboard#add_members'
      delete 'admin/dashboard/programs/:id/members/:user_id', to: 'admin_dashboard#remove_member'
      post 'admin/dashboard/sessions', to: 'admin_dashboard#create_session'
      patch 'admin/dashboard/sessions/:id', to: 'admin_dashboard#update_session'
      post 'admin/dashboard/events', to: 'admin_dashboard#create_event'
      patch 'admin/dashboard/events/:id', to: 'admin_dashboard#update_event'
      post 'admin/dashboard/resources', to: 'admin_dashboard#create_resource'
      patch 'admin/dashboard/resources/:id', to: 'admin_dashboard#update_resource'
      get 'admin/dashboard/resources/:id/file', to: 'admin_dashboard#resource_file'
      get 'admin/dashboard/:type/:id', to: 'admin_dashboard#record'
      post 'learning/resources/:id/access', to: 'platform_resources#access'
      get 'learning/resources/:id/file', to: 'platform_resources#file'

      get 'admin/reports', to: 'admin_reports#index'
      get 'admin/reports/export', to: 'admin_reports#export'
      post 'admin/reports/custom', to: 'admin_reports#save_custom'
      get 'admin/reports/custom/:report_id', to: 'admin_reports#custom'
      get 'admin/reports/custom/:report_id/export', to: 'admin_reports#custom_export'
      patch 'admin/reports/custom/:report_id', to: 'admin_reports#save_custom'
      delete 'admin/reports/custom/:report_id', to: 'admin_reports#remove_custom'
      post 'admin/reports/schedules', to: 'admin_reports#save_schedule'
      patch 'admin/reports/schedules/:schedule_id', to: 'admin_reports#save_schedule'
      delete 'admin/reports/schedules/:schedule_id', to: 'admin_reports#remove_schedule'
      post 'admin/reports/schedules/:schedule_id/run', to: 'admin_reports#run_schedule'
      get 'admin/reports/runs/:run_id/file', to: 'admin_reports#download_run'

      get 'admin/messages', to: 'admin_messages#index'
      post 'admin/messages', to: 'admin_messages#create'
      get 'admin/messages/contacts', to: 'admin_messages#contacts'
      get 'admin/messages/preferences', to: 'admin_messages#preferences'
      patch 'admin/messages/preferences', to: 'admin_messages#update_preferences'
      post 'admin/messages/broadcast', to: 'admin_messages#broadcast'
      get 'admin/messages/:id', to: 'admin_messages#show'
      get 'admin/messages/:id/messages', to: 'admin_messages#messages'
      post 'admin/messages/:id/messages', to: 'admin_messages#create_message'
      patch 'admin/messages/:id/read', to: 'admin_messages#mark_read'
      patch 'admin/messages/:id/state', to: 'admin_messages#state'
      patch 'admin/messages/:id/block', to: 'admin_messages#block'
      get 'admin/messages/:id/content', to: 'admin_messages#content'

      get 'admin/achievements', to: 'admin_achievements#index'
      post 'admin/achievements', to: 'admin_achievements#create'
      get 'admin/achievements/definitions', to: 'admin_achievements#definitions'
      patch 'admin/achievements/definitions/:definition_id', to: 'admin_achievements#update_definition'
      post 'admin/achievements/definitions/:definition_id/award', to: 'admin_achievements#award'
      get 'admin/achievements/export', to: 'admin_achievements#export'
      get 'admin/achievements/report', to: 'admin_achievements#report'
      get 'admin/achievements/:id/certificate', to: 'admin_achievements#certificate'
      post 'admin/achievements/:id/revoke', to: 'admin_achievements#revoke'
      get 'admin/achievements/:id/details', to: 'admin_achievement_details#show'
      patch 'admin/achievements/:id/details', to: 'admin_achievement_details#update'
      get 'admin/achievements/:id/sections/:section', to: 'admin_achievement_details#section'
      post 'admin/achievements/:id/criteria', to: 'admin_achievement_details#save_criterion'
      patch 'admin/achievements/:id/criteria/:criterion_id', to: 'admin_achievement_details#save_criterion'
      delete 'admin/achievements/:id/criteria/:criterion_id', to: 'admin_achievement_details#remove_criterion'
      post 'admin/achievements/:id/notes', to: 'admin_achievement_details#save_note'
      patch 'admin/achievements/:id/notes/:note_id', to: 'admin_achievement_details#save_note'
      delete 'admin/achievements/:id/notes/:note_id', to: 'admin_achievement_details#remove_note'
      get 'admin/achievements/:id/eligible_goals', to: 'admin_achievement_details#eligible_goals'
      post 'admin/achievements/:id/goals', to: 'admin_achievement_details#link_goal'
      delete 'admin/achievements/:id/goals/:link_id', to: 'admin_achievement_details#unlink_goal'
      get 'admin/achievements/:id/details/certificate', to: 'admin_achievement_details#certificate'
      post 'admin/achievements/:id/details/certificate', to: 'admin_achievement_details#issue_certificate'
      get 'admin/achievements/:id/record', to: 'admin_achievement_details#record'
      get 'admin/achievements/:id', to: 'admin_achievements#show'

      get 'admin/goals', to: 'admin_goals#index'
      get 'admin/goals/export', to: 'admin_goals#export'
      get 'admin/goals/report', to: 'admin_goals#report'
      post 'admin/goals', to: 'admin_goals#create'
      get 'admin/goals/:id/details', to: 'admin_goal_details#show'
      get 'admin/goals/:id/sections/:section', to: 'admin_goal_details#section'
      post 'admin/goals/:id/updates', to: 'admin_goal_details#save_update'
      patch 'admin/goals/:id/updates/:update_id', to: 'admin_goal_details#save_update'
      delete 'admin/goals/:id/updates/:update_id', to: 'admin_goal_details#remove_update'
      post 'admin/goals/:id/attachments', to: 'admin_goal_details#save_attachment'
      delete 'admin/goals/:id/attachments/:attachment_id', to: 'admin_goal_details#remove_attachment'
      get 'admin/goals/:id/attachments/:attachment_id/file', to: 'admin_goal_details#file'
      get 'admin/goals/:id/cover', to: 'admin_goal_details#cover'
      patch 'admin/goals/:id/cover', to: 'admin_goal_details#save_cover'
      post 'admin/goals/:id/duplicate', to: 'admin_goal_details#duplicate'
      get 'admin/goals/:id/report', to: 'admin_goal_details#report'
      get 'admin/goals/:id', to: 'admin_goals#show'
      patch 'admin/goals/:id', to: 'admin_goals#update'
      delete 'admin/goals/:id', to: 'admin_goals#destroy'
      post 'admin/goals/:id/milestones', to: 'admin_goals#save_milestone'
      patch 'admin/goals/:id/milestones/:milestone_id', to: 'admin_goals#save_milestone'
      delete 'admin/goals/:id/milestones/:milestone_id', to: 'admin_goals#remove_milestone'
      get 'admin/events', to: 'admin_events#index'
      get 'admin/events/export', to: 'admin_events#export'
      get 'admin/events/people', to: 'admin_events#people'
      get 'admin/events/import-template', to: 'admin_events#import_template'
      post 'admin/events/import-preview', to: 'admin_events#import_preview'
      post 'admin/events/import', to: 'admin_events#import_events'
      post 'admin/events', to: 'admin_events#create'
      get 'admin/events/:id/details', to: 'admin_event_details#show'
      get 'admin/events/:id/sections/:section', to: 'admin_event_details#section'
      post 'admin/events/:id/sections/:section', to: 'admin_event_details#save_item'
      patch 'admin/events/:id/sections/:section/:item_id', to: 'admin_event_details#save_item'
      delete 'admin/events/:id/sections/:section/:item_id', to: 'admin_event_details#remove_item'
      get 'admin/events/:id/materials/:item_id/file', to: 'admin_event_details#file'
      post 'admin/events/:id/announcement', to: 'admin_event_details#announcement'
      post 'admin/events/:id/duplicate', to: 'admin_event_details#duplicate'
      get 'admin/events/:id/report', to: 'admin_event_details#report'
      delete 'admin/events/:id', to: 'admin_event_details#destroy'
      get 'events/:id/details', to: 'event_content#show'
      put 'events/:id/feedback', to: 'event_content#feedback'
      get 'events/:id/materials/:item_id/file', to: 'event_content#file'
      get 'admin/events/:id', to: 'admin_events#show'
      patch 'admin/events/:id', to: 'admin_events#update'
      post 'admin/events/:id/status', to: 'admin_events#status'
      get 'admin/events/:id/calendar', to: 'admin_events#calendar'
      get 'admin/events/:id/attendees/export', to: 'admin_events#export_attendees'
      get 'admin/events/:id/attendees', to: 'admin_events#attendees'
      post 'admin/events/:id/attendees', to: 'admin_events#add_attendees'
      patch 'admin/events/:id/attendees/:registration_id', to: 'admin_events#update_attendee'
      get 'admin/resources', to: 'admin_resources#index'
      get 'admin/resources/export', to: 'admin_resources#export'
      get 'admin/resources/import-template', to: 'admin_resources#import_template'
      post 'admin/resources/import-preview', to: 'admin_resources#import_preview'
      post 'admin/resources/import', to: 'admin_resources#import_resources'
      post 'admin/resources/bulk-status', to: 'admin_resources#bulk_status'
      post 'admin/resources', to: 'admin_resources#create'
      get 'admin/resources/:id/details', to: 'admin_resource_details#show'
      patch 'admin/resources/:id/details', to: 'admin_resource_details#update'
      get 'admin/resources/:id/sections/:section', to: 'admin_resource_details#section'
      post 'admin/resources/:id/contents', to: 'admin_resource_details#save_content'
      patch 'admin/resources/:id/contents/:content_id', to: 'admin_resource_details#save_content'
      delete 'admin/resources/:id/contents/:content_id', to: 'admin_resource_details#remove_content'
      post 'admin/resources/:id/shares', to: 'admin_resource_details#share'
      delete 'admin/resources/:id/shares/:share_id', to: 'admin_resource_details#unshare'
      post 'admin/resources/:id/versions/:version_id/restore', to: 'admin_resource_details#restore'
      post 'admin/resources/:id/duplicate', to: 'admin_resource_details#duplicate'
      delete 'admin/resources/:id', to: 'admin_resource_details#destroy'
      get 'admin/resources/:id/captions', to: 'admin_resource_details#captions'
      get 'learning/resources/:id/details', to: 'platform_resources#details'
      put 'learning/resources/:id/progress', to: 'platform_resources#progress'
      put 'learning/resources/:id/feedback', to: 'platform_resources#feedback'
      post 'learning/resources/:id/contents/:content_id/access', to: 'platform_resources#content_access'
      get 'learning/resources/:id/captions', to: 'platform_resources#captions'
      get 'admin/resources/:id', to: 'admin_resources#show'
      patch 'admin/resources/:id', to: 'admin_resources#update'
      get 'admin/resources/:id/file', to: 'admin_resources#file'

      get 'admin/sessions', to: 'admin_sessions#index'
      get 'admin/sessions/options', to: 'admin_sessions#options'
      get 'admin/sessions/export', to: 'admin_sessions#export'
      get 'admin/sessions/import-template', to: 'admin_sessions#import_template'
      post 'admin/sessions/import-preview', to: 'admin_sessions#import_preview'
      post 'admin/sessions/import', to: 'admin_sessions#import_sessions'
      post 'admin/sessions', to: 'admin_sessions#create'
      get 'admin/sessions/:id/details', to: 'admin_session_details#show'
      patch 'admin/sessions/:id/details', to: 'admin_session_details#update'
      get 'admin/sessions/:id/sections/:section', to: 'admin_session_details#section'
      post 'admin/sessions/:id/assets', to: 'admin_session_details#add_asset'
      delete 'admin/sessions/:id/assets/:asset_id', to: 'admin_session_details#remove_asset'
      post 'admin/sessions/:id/assets/:asset_id/access', to: 'admin_session_details#asset_access'
      get 'admin/sessions/:id/assets/:asset_id/file', to: 'admin_session_details#asset_file'
      get 'admin/sessions/:id/materials-archive', to: 'admin_session_details#materials_archive'
      get 'admin/sessions/:id/attendees-export', to: 'admin_session_details#export_attendees'
      post 'admin/sessions/:id/notes', to: 'admin_session_details#save_note'
      patch 'admin/sessions/:id/notes/:note_id', to: 'admin_session_details#save_note'
      delete 'admin/sessions/:id/notes/:note_id', to: 'admin_session_details#remove_note'
      post 'admin/sessions/:id/follow-up', to: 'admin_session_details#follow_up'
      post 'admin/sessions/:id/duplicate', to: 'admin_session_details#duplicate'
      get 'bookings/:id/session-content', to: 'booking_sessions#show'
      post 'bookings/:id/session-assets/:asset_id/access', to: 'booking_sessions#asset_access'
      get 'bookings/:id/session-assets/:asset_id/file', to: 'booking_sessions#asset_file'
      put 'bookings/:id/session-feedback', to: 'booking_sessions#feedback'
      get 'admin/sessions/:id', to: 'admin_sessions#show'
      patch 'admin/sessions/:id', to: 'admin_sessions#update'
      patch 'admin/sessions/:id/status', to: 'admin_sessions#change_status'
      get 'admin/sessions/:id/participants', to: 'admin_sessions#participants'
      patch 'admin/sessions/:id/participants/:participant_id', to: 'admin_sessions#attendance'

      get 'admin/programs', to: 'admin_programs#index'
      get 'admin/programs/options', to: 'admin_programs#options'
      get 'admin/programs/export', to: 'admin_programs#export'
      get 'admin/programs/import-template', to: 'admin_programs#import_template'
      post 'admin/programs/import-preview', to: 'admin_programs#import_preview'
      post 'admin/programs/import', to: 'admin_programs#import_programs'
      post 'admin/programs/bulk-status', to: 'admin_programs#bulk_status'
      post 'admin/programs', to: 'admin_programs#create'
      get 'admin/programs/:id', to: 'admin_programs#show'
      patch 'admin/programs/:id', to: 'admin_programs#update'
      get 'admin/programs/:id/members', to: 'admin_programs#members'
      post 'admin/programs/:id/members', to: 'admin_programs#add_members'
      patch 'admin/programs/:id/members/:membership_id', to: 'admin_programs#update_member'
      delete 'admin/programs/:id/members/:membership_id', to: 'admin_programs#remove_member'
      get 'admin/programs/:id/records/:type', to: 'admin_programs#records'
      get 'admin/mentees', to: 'admin_mentees#index'
      get 'admin/mentees/options', to: 'admin_mentees#options'
      get 'admin/mentees/export', to: 'admin_mentees#export'
      get 'admin/mentees/import-template', to: 'admin_mentees#import_template'
      post 'admin/mentees/import-preview', to: 'admin_mentees#import_preview'
      post 'admin/mentees/import', to: 'admin_mentees#import_mentees'
      post 'admin/mentees/bulk-status', to: 'admin_mentees#bulk_status'
      post 'admin/mentees', to: 'admin_mentees#create'
      get 'admin/mentees/:id/details', to: 'admin_mentee_details#show'
      get 'admin/mentees/:id/sections/:section', to: 'admin_mentee_details#section'
      post 'admin/mentees/:id/avatar', to: 'admin_mentee_details#avatar'
      get 'admin/mentees/:id/certificates/:certificate_id', to: 'admin_mentee_details#certificate'
      get 'admin/mentees/:id', to: 'admin_mentees#show'
      patch 'admin/mentees/:id', to: 'admin_mentees#update'
      patch 'admin/mentees/:id/status', to: 'admin_mentees#status'

      get 'admin/user_access', to: 'admin_users#access'
      get 'admin/users/export', to: 'admin_users#export'
      get 'admin/users/import-template', to: 'admin_users#import_template'
      post 'admin/users/import-preview', to: 'admin_users#import_preview'
      post 'admin/users/import', to: 'admin_users#import_users'
      post 'admin/users/bulk-status', to: 'admin_users#bulk_status'
      get 'admin/users', to: 'admin_users#index'
      post 'admin/users', to: 'admin_users#create'
      get 'admin/users/:id', to: 'admin_users#show'
      patch 'admin/users/:id', to: 'admin_users#update'
      patch 'admin/users/:id/status', to: 'admin_users#status'
      post 'admin/users/:id/password', to: 'admin_users#password'
      post 'admin/users/:id/revoke-sessions', to: 'admin_users#revoke_sessions'
      get 'admin/roles', to: 'admin_roles#index'
      post 'admin/roles', to: 'admin_roles#create'
      patch 'admin/roles/:id', to: 'admin_roles#update'
      delete 'admin/roles/:id', to: 'admin_roles#destroy'

      get 'admin/system_settings', to: 'system_settings#show'
      patch 'admin/system_settings', to: 'system_settings#update'
      post 'admin/system_settings/assets/:kind', to: 'system_settings#upload_asset'
      delete 'admin/system_settings/assets/:kind', to: 'system_settings#remove_asset'
      get 'admin/system_settings/audit', to: 'system_settings#audit'
      get 'admin/system_settings/backups', to: 'system_settings#snapshots'
      post 'admin/system_settings/backups', to: 'system_settings#create_snapshot'
      get 'admin/system_settings/backups/:id', to: 'system_settings#download_snapshot'
      post 'admin/system_settings/restore', to: 'system_settings#restore'
      post 'admin/system_settings/test-email', to: 'system_settings#test_email'

      post "auth/register", to: "auth#register"
      post "auth/resend-verification", to: "auth#resend_verification"
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      post "auth/logout", to: "auth#logout"

      get "users", to: "users#index"
      get "users/", to: "users#index"
      get "users/me", to: "users#me"
      get "me/settings", to: "settings#show"
      patch "me/settings/profile", to: "settings#update_profile"
      patch "me/settings/preferences", to: "settings#update_preferences"
      patch "me/settings/password", to: "settings#password"
      delete 'me/settings/avatar', to: 'settings#remove_avatar'
      post "me/settings/avatar", to: "settings#avatar"
      get "me/settings/export", to: "settings#export"
      post "me/settings/deactivate", to: "settings#deactivate"
      get "users/verify-email", to: "users#verify_email"

      get "users/profile", to: "profiles#index"
      post "users/profile", to: "profiles#create"
      get "users/profile/:id", to: "profiles#show"
      put "users/profile/:id", to: "profiles#update"
      patch "users/profile/:id", to: "profiles#update"
      delete "users/profile/:id", to: "profiles#destroy"
      post "users/profile/:id/upload-image", to: "profiles#upload_image"

      get "roles/mentor-mentee", to: "roles#mentor_mentee"
      get "roles", to: "roles#index"
      get "roles/", to: "roles#index"
      post "roles", to: "roles#create"
      put "roles/:id", to: "roles#update"
      patch "roles/:id", to: "roles#update"
      delete "roles/:id", to: "roles#destroy"

      get "category", to: "categories#index"
      get "category/", to: "categories#index"
      post "category", to: "categories#create"
      get "category/:id", to: "categories#show"
      put "category/:id", to: "categories#update"
      patch "category/:id", to: "categories#update"
      delete "category/:id", to: "categories#destroy"

      resources :categories, only: %i[index show create update destroy] do
        collection do
          get "by-slug/:slug", action: :show_by_slug
        end
        member do
          patch :image, action: :upload_image
          delete :image, action: :destroy_image
        end
      end

      namespace :me do
        resource :mentor_profile, only: %i[show update], controller: "mentor_profiles" do
          post :avatar, action: :avatar
          delete :avatar, action: :destroy_avatar
        end
      end

      get "mentor_profiles/:id", to: "mentors#show"

      resources :mentors, only: %i[index show] do
        collection do
          get :me
          patch :me, action: :update_me
          get "me/stats", action: :stats
          post "me/availability", action: :create_availability
          patch "me/availability/:slot_id", action: :update_availability
          delete "me/availability/:slot_id", action: :destroy_availability
        end
        member do
          get :availability
          get :reviews
        end
      end

      resources :services, only: %i[index show create update destroy]
      resources :bookings, only: %i[index show create update] do
        member do
          post :review
        end
      end
      resources :reviews, only: %i[index]

      get "conversations/unread-count", to: "conversations#unread_count"
      get "conversations/contacts", to: "conversations#contacts"
      get "conversations", to: "conversations#index"
      post "conversations", to: "conversations#create"
      get "conversations/:id", to: "conversations#show"
      get "conversations/:id/messages", to: "conversations#messages"
      post "conversations/:id/messages", to: "conversations#create_message"
      patch "conversations/:id/read", to: "conversations#mark_read"
      get "conversations/:id/messages/:message_id/attachment", to: "conversations#attachment"

      get "events", to: "events#index"
      post "events", to: "events#create"
      post "events/suggestions", to: "events#suggest"
      get "events/:id", to: "events#show"
      post "events/:id/registration", to: "events#register"
      delete "events/:id/registration", to: "events#cancel_registration"
      patch "events/:id/registration", to: "events#update_registration"
      get "events/:id/calendar", to: "events#calendar"
      get "events/:id/attendees", to: "events#attendees"
      patch "events/:id/attendees/:registration_id", to: "events#update_attendance"

      get "me/achievements", to: "achievements#index"
      get "me/achievements/record", to: "achievements#record"
      get "me/achievements/certificates/:id", to: "achievements#certificate"

      get "me/activities", to: "activities#index"

      get "me/learning_area", to: "learning_area#show"
      post "me/learning_area/:course_id/enroll", to: "learning_area#enroll"
      post "me/learning_area/:course_id/lessons/:lesson_id/complete", to: "learning_area#complete_lesson"

      get "me/mentorship", to: "mentorship#show"
      post "me/mentorship/goals", to: "mentorship#create_goal"
      patch "me/mentorship/goals/:id", to: "mentorship#update_goal"
      post "me/mentorship/resources", to: "mentorship#create_resource"
      delete "me/mentorship/resources/:id", to: "mentorship#destroy_resource"

      get "me/mentee_dashboard", to: "mentee_dashboard#show"
      patch "me/mentee_profile", to: "mentee_dashboard#update_profile"
      get "me/mentee_goals", to: "mentee_goals#index"
      patch "me/goal_vision", to: "mentee_goals#update_vision"
      delete "me/mentee_goals/:id", to: "mentee_goals#destroy"
      post "me/mentee_goals/:id/milestones", to: "mentee_goals#create_milestone"
      patch "me/mentee_goals/:id/milestones/:milestone_id", to: "mentee_goals#update_milestone"
      delete "me/mentee_goals/:id/milestones/:milestone_id", to: "mentee_goals#destroy_milestone"
      post "me/mentee_goals", to: "mentee_goals#create"
      patch "me/mentee_goals/:id", to: "mentee_goals#update"

      get "dashboard", to: "dashboard#show"
      get "dashboard/", to: "dashboard#show"

      get "me/notifications", to: "notifications#workspace"
      get "me/notification_preferences", to: "notifications#preferences"
      patch "me/notification_preferences", to: "notifications#update_preferences"
      get "notifications/unread-count", to: "notifications#unread_count"
      patch "notifications/read-all", to: "notifications#read_all"
      patch "notifications/:id", to: "notifications#update"
      get "notifications", to: "notifications#index"
      get "notifications/", to: "notifications#index"
      post "notifications", to: "notifications#create"
      post "notifications/", to: "notifications#create"

      get "statistics", to: "statistics#show"
      get "statistics/", to: "statistics#show"

      post "uploads", to: "uploads#create"
      post "uploads/", to: "uploads#create"
    end
  end

  get "up", to: proc { [200, { "Content-Type" => "application/json" }, [{ status: "ok" }.to_json]] }
end
