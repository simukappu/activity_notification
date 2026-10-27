// Small formatting helpers used by templates (replacing vue-moment and vue-pluralize filters).

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const pad = (number) => String(number).padStart(2, '0')

// Formats a date in UTC as "MMM DD HH:mm" (24-hour clock) or "MMM DD hh:mm" (12-hour clock, hour12: true).
export function formatUtcDate (value, { hour12 = false } = {}) {
  const date = new Date(value)
  if (isNaN(date)) return ''
  let hours = date.getUTCHours()
  if (hour12) hours = hours % 12 || 12
  return `${MONTHS[date.getUTCMonth()]} ${pad(date.getUTCDate())} ${pad(hours)}:${pad(date.getUTCMinutes())}`
}

// Returns the singular word when count is 1, otherwise its plural form (simple English rules).
export function pluralize (word, count) {
  if (!word || count === 1) return word
  if (/[^aeiou]y$/i.test(word)) return word.slice(0, -1) + 'ies'
  if (/(s|x|z|ch|sh)$/i.test(word)) return word + 'es'
  return word + 's'
}
