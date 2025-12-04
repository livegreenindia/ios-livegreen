import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async';

/// Centralized error handling utility for user-friendly messages
class ErrorHandler {
  /// Convert Firebase Auth errors to user-friendly messages
  static String getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        // Login/Signin errors
        case 'user-not-found':
          return 'No account found with this email. Please sign up first.';
        case 'wrong-password':
          return 'Incorrect password. Please try again or reset your password.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later or reset your password.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled. Please contact support.';
        
        // Signup errors
        case 'email-already-in-use':
          return 'An account with this email already exists. Please login instead.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 6 characters with numbers and letters.';
        case 'invalid-credential':
          return 'Invalid credentials. Please check your email and password.';
        
        // Password reset
        case 'missing-email':
          return 'Please enter your email address.';
        case 'invalid-action-code':
          return 'Password reset link expired or invalid. Please request a new one.';
        
        // Google Sign-in
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email using a different sign-in method.';
        case 'sign_in_canceled':
          return 'Sign in was canceled. Please try again.';
        case 'popup-closed-by-user':
          return 'Sign in popup was closed. Please try again.';
        case 'popup-blocked':
          return 'Pop-up blocked by browser. Please allow pop-ups and try again.';
        case 'cancelled-popup-request':
          return 'Sign in was canceled.';
        case 'missing_access_token':
          return 'Authentication failed. Please try again.';
        case 'google_sign_in_failed':
          return 'Google sign in failed. Please try again or use email/password.';
        
        // Network errors
        case 'network-request-failed':
          return 'No internet connection. Please check your network and try again.';
        
        // Session errors
        case 'requires-recent-login':
          return 'Please sign in again to perform this action.';
        case 'user-token-expired':
          return 'Your session has expired. Please sign in again.';
        
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }
    
    return getGenericErrorMessage(error);
  }

  /// Convert Firestore errors to user-friendly messages
  static String getFirestoreErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to access this data. Please sign in again.';
        case 'not-found':
          return 'Data not found. Please try refreshing the page.';
        case 'already-exists':
          return 'This data already exists.';
        case 'resource-exhausted':
          return 'Too many requests. Please wait a moment and try again.';
        case 'failed-precondition':
          return 'Operation cannot be performed. Please check your data and try again.';
        case 'aborted':
          return 'Operation was canceled. Please try again.';
        case 'out-of-range':
          return 'Invalid data range. Please check your input.';
        case 'unimplemented':
          return 'This feature is not yet available.';
        case 'internal':
          return 'Server error. Please try again later.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again in a moment.';
        case 'data-loss':
          return 'Data error occurred. Please try again.';
        case 'unauthenticated':
          return 'Please sign in to continue.';
        case 'deadline-exceeded':
          return 'Request timed out. Please try again.';
        case 'cancelled':
          return 'Operation was canceled.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    
    return getGenericErrorMessage(error);
  }

  /// Convert network errors to user-friendly messages
  static String getNetworkErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (error is TimeoutException) {
      return 'Request timed out. Please check your internet connection and try again.';
    }
    if (error is HttpException) {
      return 'Server error: ${error.message}. Please try again later.';
    }
    
    return getGenericErrorMessage(error);
  }

  /// Generic error message for unknown errors
  static String getGenericErrorMessage(dynamic error) {
    if (error == null) {
      return 'Something went wrong. Please try again.';
    }
    
    final errorString = error.toString();
    
    // Check for common patterns
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Permission denied. Please sign in again.';
    }
    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'Resource not found. Please try again.';
    }
    
    // Return a cleaned up error message
    return _cleanErrorMessage(errorString);
  }

  /// Clean up technical error messages
  static String _cleanErrorMessage(String message) {
    // Remove stack traces
    if (message.contains('\n')) {
      message = message.split('\n').first;
    }
    
    // Remove technical prefixes
    message = message
        .replaceAll('Exception: ', '')
        .replaceAll('Error: ', '')
        .replaceAll('FirebaseException: ', '')
        .replaceAll('[firebase_auth/','')
        .replaceAll('[cloud_firestore/', '')
        .replaceAll('] ', '')
        .trim();
    
    // Limit length
    if (message.length > 150) {
      message = '${message.substring(0, 147)}...';
    }
    
    return message.isNotEmpty ? message : 'Something went wrong. Please try again.';
  }

  /// Validate email format
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  /// Validate password strength
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    if (!password.contains(RegExp(r'[A-Za-z]'))) {
      return 'Password must contain at least one letter';
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    
    return null;
  }

  /// Validate name
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Name is required';
    }
    
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    return null;
  }

  /// Match passwords
  static String? validatePasswordMatch(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    
    return null;
  }
}
