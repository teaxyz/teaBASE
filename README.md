# teaBASE

The developer cockpit.

[![Download teaBASE.dmg](https://custom-icon-badges.demolab.com/badge/-Download-blue?style=for-the-badge&logo=download&logoColor=white "Download DMG")](https://teaxyz.github.io/teaBASE/download.html)

> teaBASE is a macOS ≥13.5 Preference Pane.

> [!WARNING]
> teaBASE is in *beta*, almost certainly there are edge cases we are not yet
> catering to. Please report any issues you encounter.


## Secure Development

Set up SSH as securely as possible and configure `git` to prove your identity
by signing your commits.

<img src='https://teaxyz.github.io/teaBASE/img/secure-dev.png' width=477>

Our `gpg` signing is best-in-class secure with way less bloat, hassle and
overhead than GNU’s GPG suite.

> [!TIP]
> We store your GPG private key in the macOS keychain, signed such that it
> is impossible for any other app to get it. We never expose it, it is fetched
> for as small a time as possible into memory, used to sign your commits and
> then discarded.

> [!NOTE]
> We use a custom fork of [withoutboats]’s [bpb].

[bpb]: https://github.com/pkgxdev/bpb
[withoutboats]: https://github.com/withoutboats


## Git Add-Ons

A [fork-scaled] “package manager” for the vibrant Git ecosystem.

<img src='https://teaxyz.github.io/teaBASE/img/git-addons.png' width=479>

[fork scaled]: https://github.com/pkgxdev/git-gud


## Dotfile Sync

<img src='https://teaxyz.github.io/teaBASE/img/dotfile-sync.png' width=479>

teaBASE’s dotfile sync keeps your dotfiles versioned, backed up to a private
GitHub repo and synchronized to any number of computers automatically.
You can easily override, restore or otherwise fiddle with how it works because
it’s all just `git` under the hood.

> [!NOTE]
> Dotfiles are `.` prefixed files in your home directory and are how open
> source stores configuration.

> [!CAUTION]
> [Read the script] before enabling this. \
> We have carefully made every effort to ensure data loss is impossible but:
> *this is new software!*

[Read the script]: https://github.com/teaxyz/teaBASE/blob/main/Scripts/dotfile-sync.sh


## Install & Update Common Developer Tools

<img src='https://teaxyz.github.io/teaBASE/img/dev-tooling.png' width=476>

<img src='https://teaxyz.github.io/teaBASE/img/terminals.png' width=476>

We make it easy to install popular terminals and editors and set them as
defaults. We also optionally can configure macOS to open all common programmer
file formats with your chosen editor.

## Clean Install Pack

Create an encrypted `.dmg` with your dotfiles, working source trees and
your GPG private key ready for re-import. The pack can also reinstall your
apps and tools.

<img src='https://teaxyz.github.io/teaBASE/img/clean-install-pack.png' width=476>

&nbsp;


# Contributing

> [!NOTE]
> Building teaBASE requires Xcode >=16, which requires macOS >=14.5.
> You can check device compatibility [here].

Prefpanes are fiddly.

1. Build the prefpane with Xcode.
2. Select to show the build folder from the *Product* menu
3. Quit “System Settings.app” (if open) †
4. Open the `.prefPane` product from inside the `Debug` subfolder

> † System Settings.app doesn’t seem to otherwise reload the `.prefPane`
> bundle.

Debugging is hard. In theory you can connect the debugger. In practice logging
with a `teaBASE:` prefix and filtering in “Console.app” or showing
`NSAlert`s is the path of least resistance.

[here]: https://support.apple.com/en-us/105113


## Contributing FAQ

### Why is this a Preference Pane Rather than a `.app`?

More tools like this *should* be Preference Panes in our opinion. You don’t
need Menu Bar apps or clutter in your `/Applications` for rarely used
configuration tools. If you disagree we’d like to hear your take though.


### Why is this Written in Objective-C rather than Swift?

Preference Panes are old-school and the continued integration of them into
macOS is not well documented nor well supported. We didn’t want to risk
potential deployment hassles by choosing Swift here even though we would
prefer Swift.
## TypeScript Support
These types are available via:
`ash
npm install --save-dev @types/teabase
