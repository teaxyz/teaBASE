# Clean Install Guide

## Why Clean Install?

As developers we install a lot of software. Every item could potentially
contain malware. The only way to be sure your system isn’t compromised is
a fresh installation.

It is also good to practice your restoration flow for disaster scenarios, like
losing your computer or hardware failure.

## How to Clean Install

macOS makes it easy to do a clean install. In System Settings go to “General”,
“Transfer or Reset” and click “Erase All Content and Settings”.

## Using teaBASE’s “Clean Install Pack”

Before clean installing generate your clean install pack with teaBASE.

> [!INFO]
> Add all files that are not otherwise backed up to cloud services, eg. the
> working sources for your projects.
>
> Take advantage of things like iCloud Drive to have other documents restored
> automatically.

> [!IMPORTANT]
> Transfer your pack external storage before clean installing! A USB key or
> another computer are good.

Once macOS is clean installed, transfer the pack back and open it. The bundled
`restore` script will reinstall your packages, apps and dotfile configuration.

## Restoring Other Settings

Nowadays the majority of data and settings are stored in the cloud.
However, some apps will certainly lose settings as part of a clean install.
The important thing is your data and dotfiles are restored.

> [!NOTE]
> You can take advantage of this to explore your apps with a clean slate.
> Maybe you don’t want them configured the way you used to?

> It would be potentially nice to restore GUI app settings too. If you would
> like this feature open a discussion about it and let’s plan it out.
