
# How-To Guide: Syncinary

This guide provides step-by-step instructions for completing common tasks in Syncinary. It is divided into two sections: end-user guides for using the application and developer guides for setting up, running, and testing the system.

---

# 1. End-User How-To Guides

## 1.1 How to Create a New Trip?

### Purpose
Create a new group in Syncinary to organize and plan a trip.

### Preconditions
- The user has a Syncinary account.
- The user is logged into the application.

### Steps
1. Navigate to the **My Groups** page.
2. Click **Add Group** at the bottom of the page.
![Add Groups page](howto_images/1_1_1.jpg)
3. In the **New Group** dialog, enter a name in the **Group name** field.
4. Click **Create** to create the group.
![New Groups page](howto_images/1_1_2.jpg)
5. Select the newly created group from the **My Groups** page to open it.
![My Groups page](howto_images/1_1_3.jpg)

### Expected Result
The new group appears on the **My Groups** page and can be opened to begin planning the trip.

---


## 1.2 How to Invite Members to a Trip?

### Purpose
Invite other users to join an existing Syncinary group to plan a trip together.

### Preconditions
- The user is logged into Syncinary.
- A group has already been created.
- The person being invited has a Syncinary account when using email invitations.

### Steps

**Sending an Invitation**
1. Navigate to the **My Groups** page and select the group.
2. Open the **Invite Members** dialog.
![Invite_Members page](howto_images/1_2_2.jpg)
3. Enter the user's email address in the **Add User by Email** field.
4. Select the user's role (**User** or **Admin**) from the dropdown menu.
5. Click **Send Invite** to send the invitation.
![Invite_page](howto_images/1_2_3.jpg)
6. A confirmation message appears indicating that the invitation was sent.
![Invite_confirmation](howto_images/1_2_4.jpg)

**Sharing an Invite Link**
1. Open the **Invite Members** dialog.
2. Click the copy icon next to the invite link.
3. Share the copied link with the person you want to invite.
![Invite_link](howto_images/1_2_5.jpg)

**Accepting an Invitation**
1. Log into Syncinary and navigate to **My Groups**.
2. Click **Join Group**.
![Join_group](howto_images/1_2_6.jpg)
3. Under **Pending Group Invites**, locate the invitation.
4. Click the checkmark icon to accept the invitation.
![Accept_group](howto_images/1_2_7.jpg)
5. Alternatively, enter a valid invite code under **Join Through Invite Code** and click **Join**.

### Expected Result
The invited user successfully joins the group after accepting the invitation or entering a valid invite code. The group becomes available in their **My Groups** page.

---



## 1.3 How to Split Trip Expenses?

### Purpose
Add and split trip expenses among group members using equal or custom percentage splits.

### Preconditions
- The user is logged into Syncinary.
- The user belongs to an existing group.
- Other members have joined the group if expenses will be shared.

### Steps
1. Open **My Groups** and select the group.
2. Navigate to the **Cost Splitter** page.
![Cost_Splitter](howto_images/1_3_1.jpg)
3. Under **Add a custom expense**, enter a description in the **Expense Name** field.
4. Enter the expense amount in the **Cost** field.
5. Select the group members who will share the expense.
6. Choose how to divide the expense:
   - **Equal Split:** Divide the cost equally among the selected members.
   - **Custom Split:** Assign specific percentages to each member.
![Expense](howto_images/1_3_2.jpg)
7. Click **Add** to save the expense.
8. Review the **Itemized Breakdown** to see each member's share of the expense.
9. Check the **By Person** section to view the total expenses allocated to each group member.
![Final_expense_page](howto_images/1_3_3.jpg)

### Expected Result
The expense is added to the group's **Cost Splitter**, and the total cost and each member's allocated share are updated.

---


## 1.4 How to Add Activities to an Itinerary?

### Purpose
Add activities to a group's trip itinerary to organize travel plans.

### Preconditions
- The user is logged into Syncinary.
- The user belongs to an existing group.
- A trip itinerary is available for the group.

### Steps
1. Navigate to **My Groups** and select the group.
![My_Groups](howto_images/1_1_3.jpg)
2. Open the group's **Plan Itinerary** page.
![Itinerary](howto_images/1_4_2.jpg)
3. Select the option to add an activity.
![Add_Activity](howto_images/1_4_3.jpg)
4. Enter the activity details, including its name, date, and time.
![Activity_details](howto_images/1_4_4.jpg)
5. Save the activity to the itinerary.
6. Verify that the activity appears in the itinerary.
![Activity](howto_images/1_4_5.jpg)

### Expected Result
The activity appears in the group's itinerary with its details, allowing group members to view the planned activity.

---



# 2. Developer How-To Guides



## 2.1 How to Set Up and Run the Flutter Application?

### Purpose
Set up the Flutter development environment and run the Syncinary application locally.

### Preconditions
- Flutter SDK (version 3.47.2) is installed.
- Git is installed.
- A compatible IDE, such as VS Code, is available.
- The FlutterFire CLI is installed.
- The developer has access to the Syncinary GitHub repository and Firebase project `syncinary-48881`.

### Steps
1. Clone the Syncinary repository:

   ```bash
   git clone https://github.com/PrishaB/Syncinary.git
   ```

2. Navigate to the Flutter application directory:

   ```bash
   cd Syncinary/syncinary
   ```

3. Install the required Flutter dependencies:

   ```bash
   flutter pub get
   ```

4. Generate the Firebase configuration file:

   ```bash
   flutterfire configure --project=syncinary-48881
   ```

   This generates `lib/firebase_options.dart`, which is required to run the application.

5. Verify the Flutter installation:

   ```bash
   flutter doctor
   ```

6. Run the Flutter application:

   ```bash
   flutter run
   ```

7. Select an available device or browser if prompted.

8. To enable flight and hotel searches, start the backend proxy server by following Section 2.2.

### Expected Result
The Syncinary application launches successfully on the selected device or browser with Firebase Authentication and Cloud Firestore configured. Flight and hotel searches are available when the backend proxy server is running.

---

## 2.2 How to Set Up and Run the Backend Proxy Server?

### Purpose
Set up and run the Node.js backend proxy server locally to support flight and hotel searches in Syncinary.

### Preconditions
- Node.js (version 20.6 or later) and npm are installed.
- The Syncinary repository is available locally.
- Required API keys are available.

### Steps
1. Open a terminal and navigate to the proxy directory:

   ```bash
   cd proxy
   ```

2. Install the required dependencies:

   ```bash
   npm install
   ```

3. Copy `.env.example` to a new file named `.env` in the proxy directory.

4. Configure the required API keys in `.env`, including the SerpApi key for flight and hotel searches and the Google Maps API key for airport location searches.

5. Start the proxy server:

   ```bash
   node --env-file=.env server.js
   ```

6. Verify that the server is running by opening:

   ```text
   http://localhost:3000/hotels
   ```

   A response indicating missing required parameters (HTTP 400) confirms that the endpoint is reachable.

### Expected Result
The backend proxy server runs locally and is available at `http://localhost:3000`. The Flutter application can send flight and hotel search requests to the proxy.

---

## 2.3 How to Run Backend API Tests?

### Purpose
Run automated tests to verify the functionality of the Syncinary backend API.

### Preconditions
- Node.js and npm are installed.
- The Syncinary repository is available locally.
- Backend dependencies are installed.

### Steps
1. Open a terminal and navigate to the proxy directory:

   ```bash
   cd proxy
   ```

2. Run the backend test suite:

   ```bash
   npm test
   ```

3. Wait for the tests to complete.

4. Review the terminal output to identify passed, failed, or skipped tests.

5. If any tests fail, review the reported errors and corresponding test files.

### Expected Result
The terminal displays the results of the backend tests, including the number of tests passed, failed, and skipped. A successful test run completes without failures.

---
## 2.4 How to Run Flutter Widget Tests?

### Purpose
Run automated Flutter tests to verify the functionality of the Syncinary application's user interface.

### Preconditions
- Flutter SDK is installed.
- The Syncinary repository is available locally.
- Flutter dependencies have been installed using `flutter pub get`.

### Steps
1. Open a terminal and navigate to the Flutter application directory:

   ```bash
   cd syncinary
   ```

2. Run the Flutter test suite:

   ```bash
   flutter test --coverage
   ```

3. Wait for the tests to complete.

4. Review the terminal output to identify passed and failed tests.

5. Check the generated coverage file:

   ```text
   coverage/lcov.info
   ```

6. If any tests fail, review the reported errors and the corresponding test files in the `test/` directory.

### Expected Result
The Flutter test suite completes without failures, and a coverage report is generated at `coverage/lcov.info`.

---
