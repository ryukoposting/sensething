Gem::Specification.new do |s|
  s.name      = 'sensething'
  s.version   = '0.0.2'
  s.platform  = Gem::Platform::RUBY
  s.summary   = 'Simple-yet-powerful sensor logging utility for Linux'
  s.description = 'System-wide sensor data logging system with support for hwmon and nvidia-smi.'
  s.authors   = ['Evan Perry Grove']
  s.email     = ['evan@4grove.com']
  s.homepage  = 'https://hardfault.life'
  s.license   = 'GPL-3.0-only'
  s.files     = Dir.glob('{lib,bin}/**/*') # This includes all files under the lib directory recursively, so we don't have to add each one individually.
  s.require_path = 'lib'
  s.executables = ['sensething']
end
