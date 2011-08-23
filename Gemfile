source 'http://rubygems.org'

gem 'rails', '3.1.0.rc6'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'mysql2'
gem "sass-rails", "~> 3.1.0.rc.6"
gem 'coffee-rails', '~> 3.1.0.rc.6'
gem 'uglifier'


# Use unicorn as the web server
gem 'unicorn'

gem 'devise', '1.4.2'

gem 'jquery-rails'

gem 'table_for_collection'

gem 'haml', '3.1.2'

gem 'warden', '1.0.4'

gem 'inherited_resources'

# EDGE version adds maxlength to fields based on validations.
# Stable Version 1.4.2 doesn't implement it yet.
gem 'simple_form', git: 'git://github.com/plataformatec/simple_form.git'

gem 'dynamic_form'

# Version from master branch works not well when SQL query contains HAVING and
# GROUP BY statements. We are using version of will_paginate patched by me (Alexey Artamonov).
# I'm going to pull my fixes to master branch, when I'll do it and patches will be
# accepted, I'll change the git url to git://github.com/mislav/will_paginate.git
gem 'will_paginate', git: 'git://github.com/useruby/will_paginate.git'

gem 'state_machine'

gem 'recaptcha', require: 'recaptcha/rails'

gem 'active_reload', group: 'development'

gem 'aws-ses', '~> 0.4.3', require: 'aws/ses'

gem 'fast-aes'

gem 'resque'

# Easy start of resque and server
gem 'foreman'

group :development, :test, :staging do
  gem 'factory_girl_rails', '1.1.0'
  gem 'execjs'
  gem 'therubyracer'

  gem 'capistrano', '2.8.0'
  gem 'capistrano-ext', '1.2.1'
  gem 'rvm', '1.6.20'

  gem 'rspec-rails', '2.6.1'
  gem 'capybara'
  gem 'propel', '0.4.2'

  gem 'simplecov', '>= 0.4.0', :require => false
  gem 'timecop'

  # We are using this gem for importing fake data to db, data for development environment
  # located in this folder: db/fixtures/development/ for import data need to call following
  # command: rake db:seed_fu
  # master brunch not compatible with rails 3.1, that's why we're using branch 'rails-3-1'
  gem 'seed-fu', git: 'git://github.com/mbleigh/seed-fu.git', branch: 'rails-3-1'

  gem 'ruby-debug19'
end
