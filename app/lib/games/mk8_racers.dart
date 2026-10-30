// Mario Kart 8 Deluxe's ids for a racer's character and items (the race message's drv, itm and itm2) → Spanish names. The characters are the names the game shows
// (its EUes text) in the order of its character list; the items, which the game shows only as icons, have their usual Spanish names, in the order of the game's
// item ids (its table from an item id to the item box's icon). A newer game build may add to the lists.

const _drivers = [
  'Mario',
  'Luigi',
  'Peach',
  'Daisy',
  'Yoshi',
  'Toad',
  'Toadette',
  'Koopa',
  'Bowser',
  'Donkey Kong',
  'Wario',
  'Waluigi',
  'Estela',
  'Mario de metal',
  'Peach de oro rosa',
  'Lakitu',
  'Shy Guy',
  'Bebé Mario',
  'Bebé Luigi',
  'Bebé Peach',
  'Bebé Daisy',
  'Bebé Estela',
  'Larry',
  'Lemmy',
  'Wendy',
  'Ludwig',
  'Iggy',
  'Roy',
  'Morton',
  'Mii',
  'Mario Tanuki',
  'Link',
  'Aldeano',
  'Canela',
  'Peach Felina',
  'Bowsitos',
  'Aldeana',
  'Mario Dorado',
  'Huesitos',
  'Bowsy',
  'Rey Boo',
  'Inkling chica',
  'Inkling chico',
  'Link',
  'Birdo',
  'Kamek',
  'Floro Piraña',
  'Floruga',
  'Diddy Kong',
  'Funky Kong',
  'Peachette',
  'Pauline',
  'Mii',
];

const _items = [
  'Plátano',
  'Caparazón verde',
  'Caparazón rojo',
  'Champiñón',
  'Bob-omb',
  'Blooper',
  'Caparazón azul',
  'Triple champiñón',
  'Superestrella',
  'Bill Bala',
  'Rayo',
  'Champiñón dorado',
  'Flor de fuego',
  'Planta Piraña',
  'Flor bumerán',
  'Moneda',
  'Superbocina',
  'Triple plátano',
  'Triple caparazón verde',
  'Triple caparazón rojo',
  'Ocho loco',
  'Pluma',
  'Boo',
];

/// The character's name for a game id ("Rey Boo"); empty for an unknown one
String driverName(int? id) => listName(_drivers, id);

/// An item's name ("Champiñón"); empty for none (-1) or an unknown id
String itemName(int? id) => listName(_items, id);

/// The name at id in a list of names; empty when there is none
String listName(List<String> names, int? id) =>
    id != null && id >= 0 && id < names.length ? names[id] : '';
