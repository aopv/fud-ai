# Asset Credits

Exercise data, names, instructions, and legacy reference images in the Workouts tab come from the [Free Exercise DB](https://github.com/yuhonas/free-exercise-db) and are bundled locally under `ios/calorietracker/Resources/FreeExerciseDB/` (see its `LICENSE.md` and `README.md`). Fud AI's replacement exercise illustrations are original Imagen-generated raster artwork: each generation uses one approved Fud AI male or female identity sheet for recurring character/style consistency and one exact legacy Free Exercise DB endpoint image only as the pose and equipment reference. Generated masters are background-normalized and checked against that endpoint; equipment, character, anatomy, and artifacts also require manual review. Only complete two-frame pairs that pass automated and manual QA are packaged as optimized 768 px transparent WebP assets. This replacement set is still being built, so exercises without an accepted gender-specific pair continue to use the bundled legacy Free Exercise DB images. No pose extraction or image generation runs in the app.

Barcode product lookups are powered by the [Open Food Facts](https://world.openfoodfacts.org) database, queried live via its public API. Open Food Facts data is available under the [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/); the database is made by a community of contributors. Fud AI does not bundle the database — nutrition facts are fetched per scanned barcode.

App icon artwork was provided by the project owner and bundled locally in the asset catalogs.

The pixel-art tip icons in the iOS Tip Jar (Settings → Leave a Tip) were generated with [PixelLab](https://www.pixellab.ai) and are bundled in the iOS asset catalog.

Muscle glyph assets (the muscle-filter icons in the Workouts tab) are cropped/rasterized derivatives of SVG muscle paths from [`react-muscle-highlighter`](https://github.com/soroojshehryar/react-muscle-highlighter) 1.2.0, MIT License. The generated app assets are bundled locally (iOS asset catalog, Android `app/src/main/assets/muscle/`) and do not depend on the upstream repository at runtime.

Copyright (c) 2024 My Muscle Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
