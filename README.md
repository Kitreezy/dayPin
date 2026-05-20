# DayPin

A personalized iOS app for daily note-taking.
 Create:
- Text cards.
- Save photos and pin them as interactive notes.
- Create link notes.

Group them into folders—everything is tied to a specific day.

You can set a reminder for a note and personalize the color scheme to suit your needs.

Built with UIKit. No dependencies except WidgetKit and a small Lottie animation.

---

## What it does

- **Today** - card feed for the current day, swipe to delete, undo
- **Calendar** - browse any past or future day
- **Folders** - group cards by topic, custom color and cover photo
- **Widgets** - glanceable summary on the home screen

## Stack

- Swift 5.9 · UIKit · iOS 17+
- NSLayoutConstraint (no SnapKit, no Storyboards)
- UserDefaults + JSON persistence
- WidgetKit
- Lottie (empty states)

## Architecture

Plain MVC. One responsibility per file. 
Screens talk through NotificationCenter - no Combine, no RxSwift.

## Localisation

Russian and English, switchable inside the app without restart.

## Running

Clone -> open `DayPin.xcodeproj` -> select a simulator -> Run.
