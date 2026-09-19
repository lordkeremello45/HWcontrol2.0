# Unit Tests

The repository uses language-native test systems.

## C++

The native engine is validated with CTest. The suite covers defensive/runtime scenarios such as invalid model paths, repeated failed initialization, invalid telemetry and BSOD Shield heartbeat behavior.

## Go

The bridge runs:

```sh
go test -count=1 ./...
```

## Flutter

The dashboard runs:

```sh
flutter analyze
flutter test --no-pub
```
