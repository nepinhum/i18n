# V i18n

A lightweight V port of nicksnyder's go-i18n package, providing simple message localization, bundle loading and translation helpers for V applications.

**Installing via `v install nepinhum.i18n`**

## Manual Messages

```v
import i18n

mut bundle := i18n.new_bundle('en')!
bundle.add_messages('en', [
	i18n.Message{
		id: 'Cats'
		one: 'I have {{.PluralCount}} cat'
		other: 'I have {{.PluralCount}} cats'
	},
])!

localizer := i18n.new_localizer(bundle, ['en-US,en;q=0.9'])!
text := localizer.localize(i18n.LocalizeConfig{
	message_id: 'Cats'
	plural_count: i18n.plural_count_int(2)
})!

assert text == 'I have 2 cats'
```

## TOML Messages

```toml
hello = "Hello"

[cart]
other = "{{.Name}} has {{.PluralCount}} items"

[Cats]
one = "I have {{.PluralCount}} cat"
other = "I have {{.PluralCount}} cats"
```

```v
mut bundle := i18n.new_bundle('en')!
bundle.load_message_file('active.en.toml')!

localizer := i18n.new_localizer(bundle, ['en'])!
text := localizer.localize(i18n.LocalizeConfig{
	message_id: 'hello'
})!
```

The language tag is derived from the file name. For example,
`active.en.toml` loads `en` and `locales/pt-BR.toml` loads `pt-BR`.

## Supported Template Subset

Templates support only dot lookups with string data:

```text
{{.Name}}
{{.PluralCount}}
```

Custom delimiters can be set per message with `left_delim` / `right_delim` or
go-i18n style `leftDelim` / `rightDelim` in TOML.
