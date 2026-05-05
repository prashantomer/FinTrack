CLIENT_ERRORS_LOGGER = ActiveSupport::Logger.new(
  Rails.root.join("log/client_errors.log"),
  10,
  10.megabytes
)
CLIENT_ERRORS_LOGGER.formatter = ->(severity, time, _progname, msg) {
  "[#{time.iso8601}] #{severity}: #{msg}\n"
}
