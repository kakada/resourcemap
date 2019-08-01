InsteddTelemetry.setup do |config|

  # Load settings from yml
  # config_path = File.join(Rails.root, 'config', 'telemetry.yml')
  # custom_config = File.exists?(config_path) ? YAML.load(ERB.new(File.read(config_path)).result).with_indifferent_access : nil
  #
  #  if custom_config.present?
  #    config.server_url           = custom_config[:server_url]                   if custom_config.include? :server_url
  #    config.period_size          = custom_config[:period_size_hours].hours      if custom_config.include? :period_size_hours
  #    config.process_run_interval = custom_config[:run_interval_minutes].minutes if custom_config.include? :run_interval_minutes
  #  end

  # Telemetry server URL
  config.server_url = "http://telemetry.instedd.org"

  # Telemetry remote API port, where the socket listens
  config.api_port = 8089

  # Application name
  config.application = 'agrimap'

   config.add_collector Telemetry::ActivitiesCollector
   config.add_collector Telemetry::AlertConditionsCollector
   config.add_collector Telemetry::MembershipsCollector
   config.add_collector Telemetry::NewCollectionsCollector
   config.add_collector Telemetry::SitesCollector
   config.add_collector Telemetry::FieldsCollector
   config.add_collector Telemetry::AccountsCollector

end
