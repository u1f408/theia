# Theia

Discord bot for The Iris System's server.

Forked from [Rogare](https://github.com/storily/rogare), which is the Ruby
portion of Sassbot, the NZ NaNoWriMo Discord bot. This README is mostly
the same as from Rogare.

## Configuration

- `DISCORD_TOKEN=` The discord bot token.

- `RACK_ENV=` Currently only used for Bundler loading. Defaults to `production`.

- `DATABASE_URL=` Points to a Postgres server (defaults to a local server).

- `DB_SCHEMA=` The database schema to use (for namespacing inside a single Postgres instance, defaults to `public`).

- `COMMANDS_WHITELIST=` (Optional, useful in dev.) Only loads the comma-separated commands.

## Installation & Development

To run locally:

1. Create a Postgres database,
2. Clone this repo,
3. Create a `.env` file with the configuration above in the form `KEY="value"`,
4. Install the dependencies: `bundle`,
5. Run the migrations: `rake db:migrate`,
6. Start the bot: `foreman start`.

You might need to prefix commands with `bundle exec`.

The bot needs to be restarted at every change.

The bot was previously a Cinch IRC bot, so has peculiarities from that time.

After creating a migration, run it with `rake db:migrate`, then immediately
run `rake db:redo`, to test its rollback.

Use `rake console` to get a shell with most of the same context as the app.
Note that commands are not loaded automatically.
