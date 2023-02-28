![Swift Logo](https://developer.apple.com/swift/images/swift-logo.svg)

# Outset - The Swift Port

The swift port of Outset is a direct feature for feature (almost) replacement for the python version of Outset.

The project is compiled against the macOS 10.13 SDK so in theory it should run on macOS 10.13 High Sierra or newer although I'd highly recommend macOS 10.15+

## Why

Why not?

Primary reasons for porting to swift are:
 - An exercise in writing a command line utility taking advantage of the [Swift Argument Parser](https://github.com/apple/swift-argument-parser)

 - Reduction in dependencies making deployment easier (one package, no opportunity to trigger python install dialogs)


## What Isn't ported

Recent version of macos restrict the installation of `.mobileconfig` files in a useful way outside of MDM and from macOS 11 Big Sur onwards, the `profiles` command can no longer be used to install configuration profiles, so makes no sense to continue support for this feature.

## What's installed

As well as the compiled `outset` binary, the pkg also includes some other files

### Agents
`/Library/LaunchDaemons/` `/Library/LaunchAgents/`

Updated with the `AssociatedBundleIdentifiers` key so under macOS 13, Login Items show everything under the 'Outset' title

### Outset.app

![Outset Icon](https://github.com/bartreardon/outset/blob/master/swift/outset/outset/Assets.xcassets/AppIcon.appiconset/outset.png_32x32@2x.png?raw=true) 

`/usr/local/outset/Outset.app`

Apart from being an app bundle, this app has the BundleID of `io.macadmins.Outset` which is used to show in macOS 13 Login Items under the same app bundle and with an icon. In addition to this, this app will contain code to create and manage the outset launch items from macOS 13 onwards

(the icon is a green representation of the SF Symbol `folder.fill.badge.gearshape`)

## Building the project

Add your developer certificate in the signing and capabilities of both the "outset" and "Outset App Bundle" build targets in Xcode. Select the "Outset Installer Package" scheme and build. This should generate an `Outset.pkg` in your `Build/Products/Release` directory.


