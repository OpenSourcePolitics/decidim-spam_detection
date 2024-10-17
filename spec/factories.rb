# frozen_string_literal: true

require "decidim/spam_detection/test/factories"

FactoryBot.modify do
  factory :user, class: "Decidim::User" do
    email { generate(:email) }
    name { generate(:name) }
    nickname { generate(:nickname) }
    organization
    locale { organization.default_locale }
    tos_agreement { "1" }
    avatar { Decidim::Dev.test_file("avatar.jpg", "image/jpeg") }
    personal_url { Faker::Internet.url }
    about { "<script>alert(\"ABOUT\");</script>#{Faker::Lorem.paragraph(sentence_count: 2)}" }
    confirmation_sent_at { Time.current }
    accepted_tos_version { organization.tos_version }
    notifications_sending_frequency { "real_time" }
    email_on_moderations { true }
    password_updated_at { Time.current }
    previous_passwords { [] }
    extended_data { {} }

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :blocked do
      blocked { true }
      blocked_at { Time.current }
      extended_data { { user_name: generate(:name) } }
      name { "Blocked user" }
    end

    trait :deleted do
      email { "" }
      deleted_at { Time.current }
    end

    trait :admin_terms_accepted do
      admin_terms_accepted_at { Time.current }
    end

    trait :admin do
      admin { true }
      admin_terms_accepted
    end

    trait :user_manager do
      roles { ["user_manager"] }
      admin_terms_accepted
    end

    trait :managed do
      email { "" }
      password { "" }
      password_confirmation { "" }
      encrypted_password { "" }
      managed { true }
    end

    trait :officialized do
      officialized_at { Time.current }
      officialized_as { generate_localized_title }
    end

    after(:build) do |user, evaluator|
      # We have specs that call e.g. `create(:user, admin: true)` where we need
      # to do this to ensure the user creation does not fail due to the short
      # password.
      user.password ||= evaluator.password || "decidim123456789"
      user.password_confirmation ||= evaluator.password_confirmation || user.password
    end

    trait :marked_as_spam do
      after(:build) do |user|
        user.extended_data = user.extended_data
                                 .dup
                                 .deep_merge({ spam_detection: { reported_at: 1.day.ago } })
      end
    end

    trait :marked_as_spam_very_sure do
      after(:build) do |user|
        user.extended_data = user.extended_data
                                 .dup
                                 .deep_merge({ spam_detection: { reported_at: 1.day.ago, probability: 0.99 } })

      end
    end

    trait :unmarked_as_spam do
      after(:build) do |user|
        user.extended_data = user.extended_data
                                 .dup
                                 .deep_merge({ spam_detection: { unreported_at: 1.day.ago } })
      end
    end

    trait :blocked_as_spam do
      after(:build) do |user|
        user.extended_data = user.extended_data
                                 .dup
                                 .deep_merge({ spam_detection: { blocked_at: 1.day.ago } })
      end
    end

    trait :unblocked_as_spam do
      after(:build) do |user|
        user.extended_data = user.extended_data
                                 .dup
                                 .deep_merge({ spam_detection: { unblocked_at: 1.day.ago } })
      end
    end
  end
end
