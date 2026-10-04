Each subfolder here must be named exactly like one of the labels in
../labels.json, and contain bark/trunk close-up photos of that species.
This folder is a structure example only — it intentionally ships with no
images. See the "Collecting training photos" section of ../README.md for
where to source them.

data_sample/
  Mahogany/        <- permit dropdown species (reported by /predict)
  Mango/            "
  Gmelina/          "
  Acacia/           "
  Narra/            "
  Ipil_Ipil/        "
  Coconut/          "
  White_Lauan/      "
  Guijo/            "
  Apitong/          "
  Red_Lauan/        "
  Mayapis/          "
  Tindalo/          "
  Bolongeta/        "
  Malaikmo/         "
  Bayanti/          "
  Malatanglin/      "
  Unknown_Noise/   <- non-bark/background photos (leaves, random objects,
                      blurry shots, other species) so the model learns to
                      abstain instead of force-fitting every photo into one
                      of the 17 species above. Never reported by /predict.
