# Tests
Each test directory represents a different situation that `up` should be able to handle.\
## Usage
### Running a test
 1. Enter the directory for the test you want to run
 2. Use the provided `setup.sh` script to create the test directory structure 
 3. Run `up` according to the instructions in the given `readme.md`
 4. Check your results against the expected result in the given `readme.md`
### Debugging tips
 - Build `up` with debug information (`build.sh debug`)
 - Run `up` with `strace` to track syscalls (`strace {pathto}/up {args}`)
 - Learn the syscalls (Most syscall docs are meant for C, so read carefully)
 - Setup `gdb` (There's lots of gdb layouts online, but if you don't trust random people's code, running `help tui layout` in gdb will show all the built in options)
 - Learn to use `gdb` (The docs are pretty spartan but there's lots of tutorials/cheatsheets online, keep in mind a lot of these will be focused on debugging C rather than ASM)
 - Ensure you have coredumps enabled (How this works may depend on your system, most people can use `ulimit -c {max_size|"unlimited"}` to enable them, but you'll need a tool to analyze them, i.e. gdb)
## Creating a new test
### What should it do?
Tests should represent the conditions of a semi-realistic situation that will stress the program and may cause it to crash or even mangle data. \
These should be consistently repeatable, with a clear distinction between success and failure
### What should it include?
A test directory must have at least 3 files:\
**1. A `.gitignore`**\
This one is pretty simple, the `.gitignore` should ensure that none of the files create in the process of testing make it to the repo.\
In most cases, the `gitignore.example` found in the same directory as this readme will work just fine\
**2. A `setup.sh`**\
This script should do exactly what you'd expect, setup the environment for the test.\
A valid `setup.sh` has a few requirements:
 - Minimal dependencies\
Try to avoid using outside programs wherever possible, any dependencies outside of core utils should be checked for prior to any kind of setup
 - Cleanup\
Cleanup should occur before the setup, and must, at minimum, clean the environment assuming a successful completion of the test, ideally cleanup should work even if the test fails, but this isn't always realistic
 - Fail safe\
Try to ensure that if some part of the setup fails the script dies gracefully, but at minimum the user should be notified if the environment may not be as expected
 - Persistent, local changes\
The setup should only make static changes that apply only to the testing environment, any changes that could be lost by restarting your system (e.g. environment variables, background proccesses, etc.) should be part of the test procedure, not the setup
 - **DO NOT START THE TEST IN THE SETUP**\
The setup script is *only* for preparing the environment, `up` should not be called, the user should be able to run the test at any time of their choosing following the setup.\
**3. A `readme.md`**\
This readme should have at least the following three parts, formatting isn't important, but a template is provided at `example.readme.md`\
 - About\
Describe what the goal of the test is, a brief explanation of what it does, what the environment should look like after the setup, e.g. an ascii tree of the directory structure, and how to set it up, i.e. any configuration/input/dependency is required for the setup script
 - Running\
Explain how the test should be carried out, e.g. what commands to run and where
 - Validating\
Explain how the user can check if the test was successful, this could be an ascii tree of the expected result, or a script that checks automatically, any that provides consistent and accurate validation of the test
### Is that all?
Your test directory is not at all limited to these three files, you can add any number of helper scripts, configuration files, validation scripts, etc.\
Any new scripts are beholden to the requirements of usage, i.e. a helper script run by the setup script must check its dependencies and make only persistant local changes\
The included tests provide good examples
