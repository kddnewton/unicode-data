# Unicode::Data

A Ruby wrapping for the unicode character data set.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "unicode-data"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install unicode-data

## Usage

When this gem is installed, it will automatically download the unicode character data set to a temporary zip file and generate a list of properties from that zip file. You can use this information (under `lib/unicode/data/derived.txt`) to implement, for example, a regular expression engine that can respect the unicode semantics defined by the [unicode technical standard](https://unicode.org/reports/tr18/). At the moment the list of properties generated includes:

* General Categories
* Blocks
* Ages
* Scripts
* Script Extensions
* Core Properties (Math, Alphabetic, Lowercase, Case_Ignorable, etc.)
* Prop List Properties (White_Space, Bidi_Control, Terminal_Punctuation, etc.)

This lines up to almost all of the [Onigmo](https://github.com/k-takata/Onigmo/blob/master/doc/UnicodeProps.txt) unicode support (and a lot more), with the exception of:

* POSIX brackets
* Emoji

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kddnewton/unicode-data.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
