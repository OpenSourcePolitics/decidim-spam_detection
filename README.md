# Decidim::SpamDetection
[![codecov](https://codecov.io/gh/OpenSourcePolitics/decidim-spam_detection/branch/master/graph/badge.svg?token=eJu34XLlVu)](https://codecov.io/gh/OpenSourcePolitics/decidim-spam_detection)
![Tests](https://github.com/opensourcepolitics/decidim-spam_detection/actions/workflows/tests.yml/badge.svg)
![Tests](https://github.com/opensourcepolitics/decidim-spam_detection/actions/workflows/lint.yml/badge.svg)

## Usage

SpamDetection is a detection bot made by OpenSourcePolitics. It works with a [spam detection service](https://github.com/OpenSourcePolitics/spam_detection) 
which marks the user with a spam probability score, between 0.7 
and 0.99 it is probable, and above 0.99 it is very sure.

By default, the bot does not blocks the user, it only reports them.
All reports and blocks are made like regular Decidim ones.

### Installation

Add this line to your application's Gemfile:

```ruby
gem "decidim-spam_detection", git: "https://github.com/OpenSourcePolitics/decidim-spam_detection.git"
```

And then execute:

```bash
bundle exec rake decidim:spam_detection:mark_users
```

if you are using sidekiq scheduler you can use the following configuration:
```
:queues:
- user_report
- block_user
- scheduled

:schedule:
    DetectSpamUsers:
    cron: '0 0 8 * * *' # Run at 08:00
    class: Decidim::SpamDetection::MarkUsersJob
    queue: scheduled
```

### Further configuration
list of env var, default value and their usage:
```
SPAM_DETECTION_API_AUTH_TOKEN
    default_value: dummy
    usage: Token auth for authentication used by external service, ask us for more details
SPAM_DETECTION_API_URL 
    default_value: "http://localhost:8080/api"
    usage: URL of the external service
SPAM_DETECTION_NAME 
    default_value: "spam detection bot"
    usage: Name used by the spam detection bot
SPAM_DETECTION_NICKNAME 
    default_value: "Spam_detection_bot"
    usage: Nickname used by the spam detection bot
SPAM_DETECTION_EMAIL 
    default_value: "spam_detection_bot@opensourcepolitcs.eu"
    usage: Email used by the spam detection bot
PERFORM_BLOCK_USER 
    default_value: false
    usage: Determine if the bot can perform blocking, default mode is just report
```

## API usage
We can provide the detection service, please check us out at [contact@opensourcepolitics.eu](mailto:contact@opensourcepolitics.eu)

## Contributing

See [Decidim](https://github.com/decidim/decidim).

## License

This engine is distributed under the GNU AFFERO GENERAL PUBLIC LICENSE.
