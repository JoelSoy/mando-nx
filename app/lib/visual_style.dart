// Visual skins are independent from the player's control positions and scales.
enum VisualStyle { console, gamer }

const visualStyleNames = {
  VisualStyle.console: 'Consola',
  VisualStyle.gamer: 'Gamer clásico',
};
VisualStyle readVisualStyle(Object? value) =>
    value == 'console' ? VisualStyle.console : VisualStyle.gamer;
