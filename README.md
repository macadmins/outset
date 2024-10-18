Outset
======

![Outset Icon](https://github.com/bartreardon/outset/blob/master/outset/Assets.xcassets/AppIcon.appiconset/Outset.png_128x128.png?raw=true) 

Outset is a utility application which automatically processes scripts and packages during the boot sequence, user logins, or on demand.

[Check out the wiki](https://github.com/macadmins/outset/wiki) for more information on how to use Outset or find out [how it works](https://github.com/macadmins/outset/wiki/FAQ).

## Requirements
+ macOS 10.15+

## Usage

	OPTIONS:
		--boot                  Used by launchd for scheduled runs at boot
		--login                 Used by launchd for scheduled runs at login
		--login-window          Used by launchd for scheduled runs at the login window
		--login-privileged      Used by launchd for scheduled privileged runs at login
		--on-demand             Process scripts on demand
		--login-every           Manually process scripts in login-every
		--login-once            Manually process scripts in login-once
		--cleanup               Used by launchd to clean up on-demand dir
		--add-ignored-user <username>
								Add one or more users to ignored list
		--remove-ignored-user <username>
								Remove one or more users from ignored list
		--add-override <script> Add one or more scripts to override list
		--remove-override <script>
								Remove one or more scripts from override list
		--checksum <file>       Compute the checksum (SHA256) hash of the given file. Use the keyword 'all' to compute all
								values and generate a formatted configuration plist
		--version               Show version number
		-h, --help              Show help information.


## Credits

Outset 4 is a direct feature for feature (almost) update of outset by [Joseph Chilcote](https://github.com/chilcote) written in Swift.

Maintained by [MacAdmins Open Source](https://macadmins.io) and [Bart Reardon](https://github.com/bartreardon) 


### Feature Support

Recent version of macos restrict the installation of `.mobileconfig` files in a useful way outside of MDM and from macOS 11 Big Sur onwards, the `profiles` command can no longer be used to install configuration profiles, so makes no sense to continue support for this feature.

Future releases may also remove the capability to install packages as this also is something that is better served from your MDM or other application management toolkit.

#### Classic Outset
Classic outset is available if required [as a legacy release](https://github.com/macadmins/outset/tree/main/legacy)

_Note: Classic outset, while available in this repository, is no longer maintained and there are no plans for any future updates_ 
Apart from the `Outset` app, the pkg also includes some other files:

#### Agents
`/Library/LaunchDaemons/` `/Library/LaunchAgents/`

Updated with the `AssociatedBundleIdentifiers` key so under macOS 13, Login Items show everything under the 'Outset' title

#### Outset.app

![Outset Icon](https://github.com/bartreardon/outset/blob/master/outset/Assets.xcassets/AppIcon.appiconset/Outset.png_32x32@2x.png?raw=true) 

`/usr/local/outset/Outset.app`

Apart from being an app bundle, this app has the BundleID of `io.macadmins.Outset` which is used to show in macOS 13 Login Items under the same app bundle and with an icon. 

## Building the project

Add your developer certificate in the signing and capabilities of the "Outset App Bundle" build targets in Xcode. Select the "Outset Installer Package" scheme and build. This should generate an `Outset.pkg` in your `Build/Products/Release` directory.

## License

       Copyright 2023 Mac Admins Open Source

       Licensed under the Apache License, Version 2.0 (the "License");
       you may not use this file except in compliance with the License.
       You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
