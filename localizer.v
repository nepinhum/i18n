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
	tag := localizer.resolve_preferred_tag()
	if template := localizer.bundle.template_for(tag, message_id) {
		return template, tag
	}

	default_tag := localizer.bundle.default_language()
	if tag.key() != default_tag.key() {
		if template := localizer.bundle.template_for(default_tag, message_id) {
			return template, default_tag
		}
	}

	if message_has_plural_text(default_message) {
		return new_message_template(default_message)!, default_tag
	}

	return error('message "${message_id}" not found')
}

fn (localizer Localizer) resolve_preferred_tag() LanguageTag {
	default_tag := localizer.bundle.default_language()
	return match_language(localizer.preferences, localizer.bundle.language_tags(), default_tag) or {
		default_tag
	}
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
