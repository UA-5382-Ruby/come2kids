# Contributing

## Workflow

1. Pick or create a GitHub issue.
2. Create a branch from an up-to-date `main`:

   ```bash
   git checkout main && git pull
   git checkout -b issue-<number>/short-description
   ```
3. Commit your work, run Rubocop, push the branch and open a pull request that references the
   issue (`Closes #<number>`).
4. Wait for CI to pass and for a review before merging.

## Branch naming

```
issue-<number>/short-description
```

- `<number>` is the GitHub issue number.
- `short-description` is lowercase, words separated by hyphens.

| Good | Bad |
|------|-----|
| `issue-12/add-rubocop` | `rubocop` |
| `issue-34/child-profile-model` | `my_new_feature` |
| `issue-7/fix-login-redirect` | `issue-7` |

## Code style: Rubocop

The style rules are in [`api/.rubocop.yml`](../api/.rubocop.yml). Run before every push:

```bash
cd api
bundle exec rubocop          # check the whole project
bundle exec rubocop -a       # auto-fix safe offenses
bundle exec rubocop path/to/file.rb   # check a single file
```

Fix offenses instead of disabling cops. If a rule is genuinely wrong for the project, propose a
change to `api/.rubocop.yml` in a separate pull request.

## Continuous integration

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs the `lint` job (Rubocop) on every
pull request and on pushes to `main`. A failing `lint` job must block merging.

To enforce this, a repository admin enables it once in GitHub:
**Settings -> Branches -> Add rule for `main` -> Require status checks to pass before merging ->
select `lint`**.

## Changing tool versions

Ruby and Node.js versions live only in [`.tool-versions`](../.tool-versions). After changing them,
run `asdf install` and `bundle install`, and tell the team to do the same. The Gemfile and CI read
the Ruby version from that file.
