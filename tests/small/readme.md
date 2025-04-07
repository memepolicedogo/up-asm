# Small
## About
Tests if `up` works in a basic scenario by creating a structure with just a few files and directories. To set up run `setup.sh`, the `v8/` directory should look like this:
```
v8
|-- v8
|   |-- .test
|   |-- test
|   `-- v8
|       `-- test
|-- v81
|   |-- .inner
|   `-- test
`-- v82
```
## Running
Run `up v8` in this directory
## Validating
When successfull the current directory should look like this:
```
.
|-- .gitignore
|-- readme.md
|-- setup.sh
|-- v8
|   |-- .test
|   |-- test
|   `-- v8
|       `-- test
|-- v81
|   |-- .inner
|   `-- test
`-- v82
```
