module i18n

pub struct Message {
pub:
	id          string
	hash        string
	description string
	left_delim  string
	right_delim string
	zero        string
	one         string
	two         string
	few         string
	many        string
	other       string
}

struct MessageTemplate {
	message Message
}

fn new_message_template(message Message) !MessageTemplate {
	if !message_has_plural_text(message) {
		return error('message must include at least one plural text')
	}

	return MessageTemplate{
		message: message
	}
}

fn (template MessageTemplate) text_for_form(form PluralForm) !string {
	selected := match form {
		.zero { template.message.zero }
		.one { template.message.one }
		.two { template.message.two }
		.few { template.message.few }
		.many { template.message.many }
		.other { template.message.other }
		.invalid { return error('invalid plural form') }
	}

	if selected != '' {
		return selected
	}
	if form != .other && template.message.other != '' {
		return template.message.other
	}

	return error('message text is missing for plural form')
}

fn (template MessageTemplate) render(form PluralForm, data map[string]string) !string {
	text := template.text_for_form(form)!
	return render_template(text, template.message.left_delim, template.message.right_delim, data)
}

fn is_reserved_message_key(key string) bool {
	return match normalize_message_key(key) {
		'id', 'description', 'hash', 'zero', 'one', 'two', 'few', 'many', 'other', 'translation',
		'left_delim', 'right_delim' {
			true
		}
		else {
			false
		}
	}
}

fn normalize_message_key(key string) string {
	return match key {
		'leftDelim' { 'left_delim' }
		'rightDelim' { 'right_delim' }
		else { key }
	}
}

fn message_has_plural_text(message Message) bool {
	return message.zero != '' || message.one != '' || message.two != '' || message.few != ''
		|| message.many != '' || message.other != ''
}
