const fs = require('fs');
const content = fs.readFileSync('scripts/ui/game_board_controller.gd', 'utf8');
const lines = content.split('\n');

const newLoop = [
  '\tfor tt in options:',
  '\t\tvar btn := Button.new()',
  '\t\tvar name: String = GameConstants.TICKET_NAMES.get(tt, "?")',
  '\t\tvar color: Color = GameConstants.TICKET_COLORS.get(tt, Color.GRAY)',
  '\t\tbtn.text = "  " + name',
  '\t\tbtn.custom_minimum_size = Vector2(160, 44)',
  '\t\tbtn.add_theme_font_size_override("font_size", 18)',
  '\t\tif color.v < 0.3:',
  '\t\t\tbtn.add_theme_color_override("font_color", Color("#BBBBBB"))',
  '\t\telse:',
  '\t\t\tbtn.add_theme_color_override("font_color", color)',
  '\t\tbtn.pressed.connect(_on_ticket_selected.bind(tt))',
  '\t\t_popup_content.add_child(btn)',
];

const result = [];
let i = 0;
while (i < lines.length) {
  // Find the for loop that contains color_rect (the complex one)
  if (lines[i].includes('for tt in options:') && i + 4 < lines.length && lines[i + 4].includes('color_rect')) {
    result.push(...newLoop);
    // Skip until _popup_content.add_child(btn) line
    i++;
    while (i < lines.length && !lines[i].includes('_popup_content.add_child(btn)')) {
      i++;
    }
    i++; // skip the closing line too
    continue;
  }
  result.push(lines[i]);
  i++;
}

fs.writeFileSync('scripts/ui/game_board_controller.gd', result.join('\n'));
console.log('OK: file updated, lines:', result.length);
