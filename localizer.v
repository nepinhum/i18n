module i18n

pub struct LocalizeConfig {
pub:
	message_id      string
	default_message Message
	template_data   map[string]string
	plural_count    ?PluralCount
}

pub struct Localizer {
	bundle      Bundle
	preferences []LanguageTag
}

pub fn new_localizer(bundle Bundle, languages []string) !Localizer {
	preferences := parse_language_preferences(languages)!
	return Localizer{
		bundle:      bundle
		preferences: preferences
	}
}

pub fn (localizer Localizer) localize(config LocalizeConfig) !string {
	message_id := resolve_message_id(config)!
	template, tag := localizer.resolve_template(message_id, config.default_message)!
	form := resolve_plural_form(tag, config.plural_count)!
	data := render_data(config.template_data, config.plural_count)

	return template.render(form, data)
}

fn resolve_message_id(config LocalizeConfig) !string {
	default_id := config.default_message.id
	if config.message_id != '' && default_id != '' && config.message_id != default_id {
		return error('message id mismatch: "${config.message_id}" does not match default message id "${default_id}"')
	}
	if config.message_id != '' {
		return config.message_id
	}
	if default_id != '' {
		return default_id
	}
	return error('message id cannot be empty')
}

fn (localizer Localizer) resolve_template(message_id string, default_message Message) !(MessageTemplate, LanguageTag) {
	default_tag := localizer.bundle.default_language()
	for tag in localizer.resolve_candidate_tags() {
		if template := localizer.bundle.template_for(tag, message_id) {
			return template, tag
		}
	}

	if message_has_plural_text(default_message) {
		return new_message_template(default_message)!, default_tag
	}

	return error('message "${message_id}" not found')
}

fn (localizer Localizer) resolve_candidate_tags() []LanguageTag {
	available := localizer.bundle.language_tags()
	default_tag := localizer.bundle.default_language()
	mut available_by_key := map[string]LanguageTag{}
	mut candidates := []LanguageTag{}
	mut seen := map[string]bool{}

	for tag in available {
		available_by_key[tag.key()] = tag
	}

	for tag in localizer.preferences {
		if matched := available_by_key[tag.key()] {
			append_unique_language_tag(mut candidates, mut seen, matched)
		}

		mut parent := tag
		for {
			parent = parent.parent() or { break }
			if matched := available_by_key[parent.key()] {
				append_unique_language_tag(mut candidates, mut seen, matched)
			}
		}

		for candidate in available {
			if candidate.base_key() == tag.base_key() {
				append_unique_language_tag(mut candidates, mut seen, candidate)
				break
			}
		}
	}

	append_unique_language_tag(mut candidates, mut seen, default_tag)
	return candidates
}

fn append_unique_language_tag(mut tags []LanguageTag, mut seen map[string]bool, tag LanguageTag) {
	key := tag.key()
	if seen[key] {
		return
	}
	seen[key] = true
	tags << tag
}

fn resolve_plural_form(tag LanguageTag, plural_count ?PluralCount) !PluralForm {
	if count := plural_count {
		return plural_form_for_language(tag, count)!
	}
	return .other
}

fn render_data(template_data map[string]string, plural_count ?PluralCount) map[string]string {
	mut data := map[string]string{}
	for key, value in template_data {
		data[key] = value
	}
	if count := plural_count {
		data['PluralCount'] = count.str()
	}
	return data
}
