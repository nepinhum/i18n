module i18n

import os

pub struct Bundle {
	default_tag LanguageTag
mut:
	tags      []LanguageTag
	templates map[string]MessageTemplate
}

pub fn new_bundle(default_language string) !Bundle {
	default_tag := parse_language_tag(default_language)!
	return Bundle{
		default_tag: default_tag
		tags:        [default_tag]
		templates:   map[string]MessageTemplate{}
	}
}

pub fn (bundle Bundle) default_language() LanguageTag {
	return bundle.default_tag
}

pub fn (bundle Bundle) language_tags() []LanguageTag {
	return bundle.tags.clone()
}

pub fn (mut bundle Bundle) add_messages(language string, messages []Message) ! {
	tag := parse_language_tag(language)!
	key := tag.key()
	is_new_language := !bundle.has_language_key(key)
	mut templates := map[string]MessageTemplate{}

	for message in messages {
		if message.id == '' {
			return error('message id cannot be empty')
		}
		templates[bundle_template_key(key, message.id)] = new_message_template(message)!
	}

	if is_new_language {
		bundle.tags << tag
	}
	for template_key, template in templates {
		bundle.templates[template_key] = template
	}
}

pub fn (mut bundle Bundle) load_message_file(path string) !MessageFile {
	data := os.read_file(path)!
	return bundle.parse_message_file_bytes(data.bytes(), path)!
}

pub fn (mut bundle Bundle) parse_message_file_bytes(data []u8, path string) !MessageFile {
	message_file := parse_message_file_bytes(data, path)!
	bundle.add_messages(message_file.tag.str(), message_file.messages)!
	return message_file
}

fn (bundle Bundle) template_for(tag LanguageTag, id string) !MessageTemplate {
	return bundle.template_for_key(tag.key(), id)!
}

fn (bundle Bundle) template_for_language(language string, id string) !MessageTemplate {
	tag := parse_language_tag(language)!
	return bundle.template_for(tag, id)!
}

fn (bundle Bundle) template_for_key(language_key string, id string) !MessageTemplate {
	return bundle.templates[bundle_template_key(language_key, id)] or {
		error('message "${id}" not found for language "${language_key}"')
	}
}

fn (bundle Bundle) has_language_key(key string) bool {
	for tag in bundle.tags {
		if tag.key() == key {
			return true
		}
	}
	return false
}

fn bundle_template_key(language_key string, id string) string {
	return language_key + '\x00' + id
}
