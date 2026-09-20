# Manual Test Report

## Test Information

| Field | Details |
| --- | --- |
| Test ID | ST-06 |
| Test Name | Offline and Degraded State Handling |
| Requirement ID(s) | FR-201, NFR-102 |
| Test Level | System |
| Tester | Prisha Boreddy |
| Date | 09/20/2026 |
| Priority | Medium |
| Application Version / Branch | group_updates @ 1670877 |

## Objective

Verify that Syncinary handles unavailable network services gracefully without crashing or hanging. 

## Preconditions

- Syncinary is running normally.
- The application can initially connect to its required services.
- The tester can disable network access and/or stop the proxy.

## Test Environment

| Field | Details |
| --- | --- |
| Platform | Web |
| Browser | Chrome |
| Operating System | Windows |

## Test Steps

| Step | Action | Expected Result | Actual Result | Status |
| --- | --- | --- | --- | --- |
| 1 | Launch Syncinary normally while connected to the internet. | Application loads successfully and functions normally. | Application loaded successfully and functioned normally | Pass |
| 2 | Sign in to Syncinary and navigate to the groups page. | User is successfully signed in and group information loads normally. | User signed in successfully and group info loaded normally| Pass |
| 3 | Disable the device's network connection. | Application remains open and responsive after losing network connectivity. | After refreshing, the page loaded fine but existing group disappeared. Aside from that app did remain responsive after losing network connectivity. | Pass |
| 4 | Attempt an operation requiring network access, such as creating a new group. | Application handles the failed network request without crashing or hanging and provides clear feedback to the user. | Application does not crash or hang but does not provide clear feedback to user. Instead, nothing happens.| Fail |
| 5 | Restore the device's network connection. | Application remains responsive after network connectivity is restored. | Application does remain responsive after network connectivity is restored. | Pass |
| 6 | Retry the operation that previously required network access. | The operation completes successfully after network connectivity is restored. | The operation did complete successfully once network connectivity was restored. | Pass |

## Overall Result

**Status:** Fail

Overall, page did not crash or hang after network request failed. However, it does not let the user know what the issue is and leaves it up to the user to determine what went wrong. 

## Issues / Bugs Found

- **Bug ID:** BUG-001
- **Description:** Syncinary does not display an error message when a network-dependent operation fails because the device has no network connection.
- **Related Bug Report:** BUG-001 - No Error Message Displayed When Network Connection Is Unavailable

## Evidence / Notes

N/A

# Bug Report

## Bug Information

| Field | Details |
| --- | --- |
| Bug ID | BUG-001 |
| Title | No Error Message Displayed When Network Connection Is Unavailable |
| Related Test | ST-06 |
| Reported By | Prisha Boreddy |
| Date Reported | 09/20/2026 |
| Severity | Medium |
| Priority | Medium |
| Status | Open |

## Description

When the device loses network connectivity, Syncinary does not provide the user with an error message or other indication that an operation failed because of the unavailable network connection. The application remains responsive and does not crash or hang, but the user is left to determine why the requested operation did not complete.

## Environment

| Field | Details |
| --- | --- |
| Platform | Web |
| Browser | Chrome |
| Operating System | Windows |
| Application Version / Branch | group_updates @ 1670877 |

## Preconditions

- Syncinary is running in a web browser.
- The user is signed in.
- The device initially has an active network connection.
- The user is on a page where an operation requiring network access can be performed.

## Steps to Reproduce

1. Launch Syncinary with an active network connection.
2. Sign in and navigate to the groups page.
3. Disable the device's network connection.
4. Attempt an operation requiring network access, such as creating a new group.
5. Observe the application's response.

## Expected Result

Syncinary should remain responsive and display a clear error message informing the user that the operation could not be completed due to a network or connection issue.

## Actual Result

Syncinary remains responsive and does not crash or hang. However, no error message or other feedback is displayed to explain why the operation could not be completed. The user must determine on their own that the failure was caused by the unavailable network connection.

## Evidence

N/A
