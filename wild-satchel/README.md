# wild-satchel
Restores native inventory functionality and adds support for custom items.

Public methods:
```
W.Satchel.Add(item, quantity, bNoUpdate)
W.Satchel.Remove(item, quantity, bSuppressUi)
W.Satchel.GetItemCount(item)
W.Satchel.Open(bShopMode)
```

## How to add a custom item
1. Pick a name for your item and it to `custom_items.json`. Follow the template.
2. Add your item texture to inventory_items_tu.ytd for toaster hud support. The ytd must be named as such or the icon will be small in toast feeds.
3. Finally, get a copy of your item texure, rename it as a JOAAT hash, and place it in `item_textures`.
4. Add to inventory like any other item: `W.Satchel.Add(GetHashKey("my_custom_item"), 1)`