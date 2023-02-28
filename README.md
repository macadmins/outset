Outset
======

![Outset Icon](https://github.com/bartreardon/outset/blob/master/outset/Assets.xcassets/AppIcon.appiconset/Outset.png_128x128.png?raw=true) 

Outset is a utility application which automatically processes scripts and packages during the boot sequence, user logins, or on demand.

Requirements
------------
+ macOS 10.15+

Legacy python version can be found here \<insertlink\>

Usage
-----

	OVERVIEW: This script automatically processes packages, profiles, and/or scripts at boot, on demand, and/or login.

	USAGE: outset <options>

	OPTIONS:
	--boot                  Used by launchd for scheduled runs at boot
	--login                 Used by launchd for scheduled runs at login
	--login-privileged      Used by launchd for scheduled privileged runs at login
	--on-demand             Process scripts on demand
	--login-every           Manually process scripts in login-every
	--login-once            Manually process scripts in login-once
	--cleanup               Used by launchd to clean up on-demand dir
	--add-ignored-user <username>
							Add one or more users to ignored list
	--remove-ignored-user <username>
							Remove one or more users from ignored list
	--add-overide <script>  Add one or more scripts to override list
	--remove-overide <script>
							Remove one or more scripts from override list
	--compute-sha <file>    Compute the SHA1 hash of the given file
	--version               Show version number
	-h, --help              Show help information.



See the [wiki](https://github.com/chilcote/outset/wiki) for info on how to use Outset.

Credits
-------
The swift port of Outset is a direct feature for feature (almost) replacement for the python version of Outset by Joseph Chilcote.

### What Isn't ported

Recent version of macos restrict the installation of `.mobileconfig` files in a useful way outside of MDM and from macOS 11 Big Sur onwards, the `profiles` command can no longer be used to install configuration profiles, so makes no sense to continue support for this feature.

Future releases may also remove the capability to install packages as this also is something that is better served from your MDM or other application management toolkit.

### What's installed

Appart from the `Outset` app, the pkg also includes some other files:

#### Agents
`/Library/LaunchDaemons/` `/Library/LaunchAgents/`

Updated with the `AssociatedBundleIdentifiers` key so under macOS 13, Login Items show everything under the 'Outset' title

#### Outset.app

![Outset Icon](https://github.com/bartreardon/outset/blob/master/swift/outset/outset/Assets.xcassets/AppIcon.appiconset/outset.png_32x32@2x.png?raw=true) 

`/usr/local/outset/Outset.app`

Apart from being an app bundle, this app has the BundleID of `io.macadmins.Outset` which is used to show in macOS 13 Login Items under the same app bundle and with an icon. 

## Building the project

Add your developer certificate in the signing and capabilities of the "Outset App Bundle" build targets in Xcode. Select the "Outset Installer Package" scheme and build. This should generate an `Outset.pkg` in your `Build/Products/Release` directory.

License
-------

    Copyright Joseph Chilcote

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
