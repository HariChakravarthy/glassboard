import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Wraps a Firestore stream query with a retry mechanism that catches
/// 'permission-denied' errors. This handles the transient race condition
/// where Firestore queries run immediately after auth transitions before
/// the authentication token has fully synced with the Firestore client.
Stream<T> retryOnPermissionDenied<T>(
  Stream<T> Function() streamFactory, {
  int maxRetries = 3,
  Duration delay = const Duration(milliseconds: 500),
}) {
  StreamController<T>? controller;
  StreamSubscription<T>? subscription;
  int retryCount = 0;

  void startListening() {
    try {
      subscription = streamFactory().listen(
        (data) {
          if (controller != null && !controller.isClosed) {
            controller.add(data);
          }
          retryCount = 0; // Reset on success
        },
        onError: (error) {
          if (error is FirebaseException &&
              error.code == 'permission-denied' &&
              retryCount < maxRetries) {
            retryCount++;
            debugPrint(
              'Firestore permission-denied. Retrying ($retryCount/$maxRetries) in ${delay.inMilliseconds}ms...',
            );
            subscription?.cancel();
            Future.delayed(delay, () {
              if (controller != null && !controller.isClosed) {
                startListening();
              }
            });
          } else {
            if (controller != null && !controller.isClosed) {
              controller.addError(error);
            }
          }
        },
        onDone: () {
          if (controller != null && !controller.isClosed) {
            controller.close();
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (controller != null && !controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  controller = StreamController<T>(
    onListen: startListening,
    onCancel: () {
      subscription?.cancel();
    },
  );

  return controller.stream;
}
