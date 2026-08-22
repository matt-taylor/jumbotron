# Testing with Jumbotron

Jumbotron ships FactoryBot definitions for engine-owned models. Hosts load
them explicitly in the test suite — there is no production Railtie and
FactoryBot is not a runtime gem dependency.

Back to [README](../README.md).

## Setup

```ruby
# spec/rails_helper.rb (after Rails is loaded)
require "jumbotron/testing"

Jumbotron::Testing.install! # preferred
# Jumbotron::Testing.load_factories! # factories-only / advanced
```

Call `install!` **before** any host `FactoryBot.modify` blocks so shared
factories exist when you extend them.

## Extending factories

Hosts must not redefine Jumbotron base factories. Use `FactoryBot.modify`:

```ruby
FactoryBot.modify do
  factory :jumbotron_game do
    trait :completed do
      lifecycle { "completed" }
    end
  end
end
```

## Packaging and evolution

Factory files live under `spec/factories/**` inside the gem and are included in
the gemspec. Adding or changing a shared factory is a normal Jumbotron gem
bump — hosts pick it up on upgrade.

`Jumbotron::Testing.load_factories!` is idempotent (safe to call more than
once). It loads each factory file under `Jumbotron::Engine.root/spec/factories`
explicitly; it does not append to global `FactoryBot.definition_file_paths`.

## Responsibilities

| Owner | Responsibility |
|-------|----------------|
| Jumbotron | Base factories for Jumbotron-owned models; Testing API; packaging |
| Host | `install!` in the test boot path; product traits via `FactoryBot.modify` |

## Factory invariant

Base factories construct **persistent model state only**. They must not invoke
Services, Workflows, ApplicationWorkflows, or external adapters.

## Contributors vs hosts

This guide is the **host Testing API**. Contributors working inside the Jumbotron
repository also follow workspace test standards and architecture guards under
`spec/architecture/`.
