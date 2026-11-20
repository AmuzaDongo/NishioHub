# Rails 8.1 framework defaults (file retained under its original name).
#
# `config.load_defaults 8.1` in config/application.rb enables the 8.1 defaults.
# This file is the place to record any default intentionally kept on the old
# behaviour. There are none at the moment: this is a stateless API with no
# background jobs, no websockets, and no Active Storage attachments, so the
# 8.1 defaults are safe as-is.
#
# Notable defaults now in effect (introduced in 8.0, retained in 8.1):
#   - config.active_support.to_time_preserves_timezone = :zone
#   - config.active_record.raise_on_assign_to_attr_readonly = false
#   - config.active_record.belongs_to_required_validates_foreign_key = false
#   - config.active_record.validate_migration_timestamps = true
#   - config.active_job.enqueue_after_transaction_commit = :default
#   - config.action_dispatch.strict_freshness = true
#   - config.action_controller.allow_deprecated_parameters_hash_equality = false
#
# If a future change needs the pre-8.0 behaviour, add the setting here with a
# comment explaining why.
