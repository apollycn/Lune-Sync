# Lune Sync

Lune Sync is a Luau script made with [Lune](https://lune-org.github.io/docs) for syncing your project to Roblox Studio, even offline.

## Installation

Use the package manager [rokit](https://github.com/rojo-rbx/rokit) to install Lune.
```bash
rokit add lune-org/lune@0.8.9
```

## Usage
You will need a [rojo project file](https://rojo.space/docs/v7/project-format/) to use this script. 
```bash
lune run sync <place-file-name> <[optional] rojo project file>
```

## Contributing

The current script only works with a specific file structure, pull requests are welcomed to make it available for any file structure.  

### File structure requirements
```
Project/
├── mantle/
│   └── places/
│       └── start.rblx
└── places/
    └── out/
    └── src/
    └── default.project.json
```

## License

[MIT License](https://choosealicense.com/licenses/mit/)