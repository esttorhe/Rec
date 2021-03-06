[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) 
[![Version](https://img.shields.io/cocoapods/v/Rec.svg?style=flat)](http://cocoapods.org/pods/Rec)
[![Circle CI](https://circleci.com/gh/esttorhe/Rec.svg?style=svg)](https://circleci.com/gh/esttorhe/Rec)
[![CI Status](http://img.shields.io/travis/esttorhe/Rec.svg?style=flat)](https://travis-ci.org/esttorhe/Rec) 
[![Coverage Status](https://coveralls.io/repos/esttorhe/Rec/badge.svg)](https://coveralls.io/r/esttorhe/Rec) 
[![License](https://img.shields.io/cocoapods/l/Rec.svg?style=flat)](http://cocoapods.org/pods/Rec) 
[![Platform](https://img.shields.io/cocoapods/p/Rec.svg?style=flat)](http://cocoapods.org/pods/Rec) 

# ![https://cldup.com/Q0g0iZrPlT.png](https://cldup.com/Q0g0iZrPlT.png)
Helper library to record URL requests and save them locally (great for fixtures in HTTP stubbing)
<br/><br/>

-------
<p align="center">
  <a href="#why">Why?</a> &bull; 
  <a href="#ohhttpstubs">OHHTTPStubs</a> &bull; 
  <a href="#rec"><b>Rec</b></a> &bull; 
  <a href="#error-codes"><i>Error Codes</i></a> &bull; 
  <a href="#todo">TODO</a> &bull; 
</p>
-------


# Why?
[@Orta][orta] told me once over `Skype` how he has incorporated into their `API` teams some way to have a "sample" `JSON` for each call (I'm paraphrasing) so they can actually test with «real life» sample data and even support an «offline» mode for the app for when developing while riding the :train:, etc.

Sadly for me I work at a company that does multiple projects a year and not always we control the `API` development part which kinds of "cripples" the addition of "sample" `JSON`s.

## [`OHHTTPStubs`][httpstubs]
Enter [`OHHTTPStubs`][httpstubs]; I started adding `HTTP Stubs` to my projects for testing purposes and had to manually enter the `URL` for each request and save the resulting `JSON` in each file to add it to the fixtures folder for the test cases.

As an engineer (and more importantly an overly lazy person) I decided that this was a terribly tedious and slow process; so… why not automate it?

# Rec
This is where `Rec` comes to play; it's an `NSURLProtocol` that intercepts each `NSURL` request made from `NSURLSession`s (with `defaultSessionConfiguration` & `ephemeralSessionConfiguration`) and adds itself as the delegate for the connection; once the request succeeds the framework will save it to the application's `Documents` folder (under «Fixtures» folder).

`Rec` follows in the steps of [`OHHTTPStubs`][httpstubs] and «automagically» adds itself as the listener (it does so by swizzling `defaultSessionConfiguration` & `ephemeralSessionConfiguration` and returning a "pre configured" session configuration object).

## Error Codes
Here's the list of «internal» error codes:
```swift
public enum RecordingError: ErrorType {
    /// Unable to start loading the request
    case UnableToStartLoadingRequest
    /// Failed to connect with NSURLRequest
    case FailedToConnectToWithRequest(NSURLRequest)
    /// Unable to correctly parse as a `JSON` response
    case UnableToCorrectlyParseAsJSON(NSURLRequest)
    /// Unable to get the `Document`'s directory path
    case UnableToGetDocumentsDirectoryPath
    /// Unable to extract the request's last path component for file name generation.
    case UnableToExtractRequestsLastPath(NSURLRequest)
    /// Unable to save file to path
    case UnableToSaveFileToPath(String)
    /// Unable to get a successful response from URL.
    case UnableToGetSuccessfullResponseFromRequest(NSURLRequest)
}
```

# TODO:
- [ ] Support other responses (e.g.: `xml`, etc) • [Issue #1] (https://github.com/esttorhe/Rec/issues/1)
- [ ] Support custom «save» paths • [Issue #2] (https://github.com/esttorhe/Rec/issues/2)
- [ ] Support disabling automatic «injection» • [Issue #3] (https://github.com/esttorhe/Rec/issues/3)
- [ ] Fix the race condition happening on the Example App (`println()` I'm :eyes: at you :unamused: ) • [Issue #4] (https://github.com/esttorhe/Rec/issues/4)
- [x] ~~Add support for `OS X`~~ • [Issue #5] (https://github.com/esttorhe/Rec/issues/5)

[Orta]:https://github.com/orta
[httpstubs]:https://github.com/AliSoftware/OHHTTPStubs
