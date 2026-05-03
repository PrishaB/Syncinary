**Syncinary Software Development Plan**

By: Group 5

**Project Overview**

We are building Syncinary to help groups organize trips by collecting everyone’s preferences, like budget, activities, and availability, in one place so that travel plans are not disrupted due to scattered planning across apps, miscommunication about preferences, and unclear expenses.

**Scope**

*In Scope*

To clearly define the project boundaries, it is important to identify which features and system requirements are included in the project scope and which are excluded. The following features and system requirements are considered in scope for Syncinary:

*User management and security*

* User authentication and account login.  
* Basic account security.  
* Storage of user preferences and trip-related data.

Due to Syncinary being used to coordinate travel plans between private groups, users must feel confident that their personal information and travel details are protected. These features would ensure that travel information is protected and that only authorized users can access group plans.

*Group travel coordination*

* Create travel groups  
* Establish group roles (leaders and members)

With group travel coordination being a core component of the system, implementing these features would allow multiple users to collaboratively organize trips within a shared environment. 

*Trip planning features*

* LLM-powered travel recommendations.  
* Allow for simplified trip itinerary creation.  
* Expense tracking and cost splitting.

These features also support the primary goal of the system which is to simplify collaborative trip planning. 

*Application platform*

* Web-based application accessible through a browser.

A web platform allows users to access Syncinary from multiple devices while keeping development manageable within the project timeline.

*Under Evaluation*

By implementing all these features, Syncinary will provide users with a centralized platform for securely organizing group travel, managing itineraries, and coordinating shared expenses. These capabilities represent the core functionality required for Syncinary to operate as a basic group travel planning application and are achievable within the project’s one-year development timeline. However, additional features could be added to Syncinary to enhance user experience and may be considered if time and resources allow. The following features and system requirements are being considered under evaluation for Syncinary:

*Enhanced planning features*

* AI agent for automatically generating trip plans.  
* Interactive map visualization of travel routes.  
* Road trip planning support

These features could improve planning capabilities for users but may require additional API integration and development time.

*User convenience features*

* Alternative sign-in methods (i.e. Google or Apple login)  
* SMS flight or itinerary reminders

These features would improve usability but require third-party services and would introduce additional privacy considerations.

*Booking and price information*

* Redirecting users to external booking websites.  
* Direct booking integrations.  
* Flight or hotel price history.

These features could help users make travel decisions but would depend on external APIs and service access. These would require extra development time for testing so implementing this could be nice but only if time permits.

*Platform expansion*

* Mobile companion application.

While this could improve accessibility, since people are typically carrying mobile devices, developing both a web and mobile platform may exceed the project scope.

*Advanced group management*

* Expanded role permissions for group leaders and members.

These features could improve collaboration but would require additional system complexity.

*Out of Scope*

While the features listed under evaluation could improve usability and expand the capabilities of Syncinary, they are not required for the core functionality of the system and may not be feasible within the project’s development timeline. Because the development team must prioritize essential features and work within technical and resource constraints, some functionality must be intentionally excluded from the project scope. The following features and system requirements are therefore considered out of scope for Syncinary:

*Commercial features.*

* In app bank transfers/monetary payments between users.  
* Paid feature tiers or subscriptions.  
* In-app travel bookings.  
* Advertisements.

These features require payment processing and commercial infrastructure that is outside the scope of a senior design project.

*Enterprise features.*

* Tools designed for businesses or large organizations.

Syncinary is intended for small informal travel groups rather than enterprise use.

*Communication and localization.*

* In-app messaging between users.  
* Built-in language switching.

These features would not be essential to the core planning functionality and are time intensive so adding them to the project scope would be illogical.

*Offline capability.*

* Offline application support.

Offline functionality would require additional synchronization and data management that is beyond the project’s scope.

The features listed above are excluded in order to maintain a focused and achievable project scope. The following assumptions and constraints further define the conditions under which Syncinary will be developed and explain the limitations that influenced these scope decisions.

For the scope of Syncinary we’ll have to assume the following about users, environment, and user needs:

*Users*

* Users will have reliable internet access.  
* Users are comfortable using web applications.  
* Travel groups primarily consist of friends, students or small social groups.

*Environment*

* Syncinary will run in a standard web browser environment.  
* External travel websites will remain available for booking redirection.

*User Needs*

* Users want a centralized platform for coordinating group travel plans instead of relying on multiple tools.

Syncinary will be bound by time, technical, resource, and security/compliance constraints. More specifically, the constraints that Syncinary will be bound to are:

*Time*

* The project must be completed within the one-year senior design timeline. This limits the number and complexity of features that can be implemented in Syncinary.

*Technical*

* Full booking integrations and payment systems are outside of our available development resources.  
* Some features depend on external APIs for travel data, which may affect availability and implementation complexity.

*Resources*

* The project is developed by a small student team with limited budget and infrastructure. This restricts large-scale system development.

*Security/Compliance*

* Because our application will store user information, we will need to implement basic security practices. However, full commercial compliance requirements would be outside the scope of this project.

**Requirements Elicitations & Prioritizations**

**Software Requirements**

ID System: 

FR: Functional Requirement

1xx: User Interface

2xx: Travel API Integration

3xx: User Onboarding

4xx: Data Management

5xx: Security and Permissions

NFR: Non-Functional Requirements

	1xx: Performance

	2xx: Reliability

	3xx: Usability

**Functional Requirements**

 ID: FR-101 

* Title: Multi-Page Data Transferring  
* Statement  
  * The user interface shall allow the user to navigate between all primary pages, such as the Dashboard, Trip Details, Preferences, and Booking pages, using navigation elements, like the navigation bar, with at most 2 clicks between any two.  
  * The user interface shall ensure smooth transitions, which means under 2 seconds of load time between any two pages.  
  * The user interface shall display only data associated with the currently selected trip and authenticated user.  
* Rationale  
  * Having well-structured and defined pages will allow us to break up the subsystems of our web app in a logical manner.  
* Test Method   
  * For each page-to-page link, there will be a list of data to transfer. For each of these, at least 5 tests composed of normal usage, null cases, and other possible edge cases will be conducted.  
* Supporting Context  
  * Flutter has extensive documentation on both native and user created data types.  
  * Dart has built in support for “Null Safety”.  
* Trace: SYS 102- Group Features  
* Priority: Must Have

ID: FR-102

* Title: Linking to kayak.com  
* Statement  
  * The User Interface shall link with kayak.com to provide users with a method of booking travel off of our site.  
* Rationale  
  * As a travel planner, the actual booking is one of the most important aspects but would require us to handle financial data which we do not feel comfortable with. This option provides an external solution.  
* Test Method  
  * Using kayak.com’s Deep Link program, test 50 flights and 50 hotels to prove that the travel options correctly link to relevant Kayak results.   
* Supporting Context  
  * The Kayak Deep Link program provides a method for developers to use dynamic links that route to the most relevant kayak results.  
* Trace: SYS 107- External Site Linking  
* Priority: Should Have

ID: FR-103

* Title: Cost Splitting Tool  
* Statement  
  * When a purchase is recorded, the UI shall display cost division data.  
* Rationale  
  * As a group travel app, it is important that we show cost splitting data as it is unlikely that these kinds of trips are fully paid for by one individual.  
* Test Method  
  * Import multiple mock purchases with different total prices and split them different ways amongst a group. Then, ensure each group member is paying their split share based on the total number of participating group members.  
* Supporting Context  
  * N/A  
* Trace: SYS 108- Cost Splitting  
* Priority: Must Have

ID: FR-104

* Title: AI Suggestions  
* Statement  
  * When an initial search is made, the UI shall display LLM suggestions directly related to the user’s and group’s preferences, available dates, budget constraints, and previously searched destinations and events.  
* Rationale  
  * Having LLM suggestions will make it easier for groups to find trip ideas that they may have not initially thought of.  
* Test Method  
  * Create multiple user accounts with different preferences, budget constraints, and search history. For each of these accounts, input a  consistent set of available dates and destinations and verify that the recommendations vary between users and correspond to the preferences, budget constraints, and search history.  
* Supporting Context  
  * Gemini would likely be used for this to stay within the Google ecosystem.  
* Trace: SYS 109- LLM Integration  
* Priority: Must Have

ID: FR-105

* Title: Exportable Trip Summary  
* Statement  
  * The user interface shall provide a feature to generate and download a pdf summary of the final itinerary.  
* Rationale  
  * Travelers often face unreliable internet connectivity, and having a list of the trip in an offline format would be useful in case the internet is not reachable.  
* Test Method  
  * Populate a trip with 5 itinerary items and 3 split expenses. Use the export function and verify that the pdf list of the is correct and has all the correct information.  
* Supporting Context  
  * There are several libraries that allow for generation of documents from widget data.  
* Trace: SYS 106- Group Itinerary / SYS 108- Cost Splitting  
* Priority: Should Have

 ID: FR-201 

* Title: Retrieve flight, hotel, and activity options  
* Statement  
  * The system shall allow users to search for and retrieve flights, hotels, and activities based on certain user-defined criteria and display these options with pricing, availability, and key details (flight times, hotel location, event information, etc.).  
  * The user-defined criteria shall include destination, dates, budget, and preferences.  
* Rationale  
  * Users require comprehensive travel options for making decisions on hotel, flight, and activity booking when planning trips.  
* Test Method  
  * Input valid search criteria and verify that the system returns a list of accurate flights, hotels, and activities.  
  * Ensure that each returned search result includes price, availability, and key details (flight times, hotel location, event information, etc.).  
  * Verify that 100% of the returned list of flights, hotels, and activities is accurate compared to external resources like airline or hotel websites.  
* Supporting Context  
  * Travel data will be retrieved through third-party APIs (Amadeus) when implemented.  
* Trace: SYS 105- Travel API Linking  
* Priority: Must Have

ID: FR-202

* Title: Visualize itinerary locations and routes  
* Statement  
  * The Itinerary page shall display a visual map of trip locations included in the user’s itinerary and show routes between those locations.  
* Rationale  
  * The user experience would be enhanced by having a map with trip routes and locations displayed because it allows them to understand the geographic layout of their trip and ultimately make better planning decisions.  
* Test Method  
  * Create 10 sample itineraries to ensure the routing is working correctly.  
  * Test potential edge cases including duplicate locations or places with invalid location data.  
  * Verify that the map correctly updates with newly added, removed, or reordered itinerary locations.  
* Supporting Context  
  * Map visualization will be implemented into our project using external services (Google Maps API).  
* Trace: SYS 105-Travel API Linking  
* Priority: Should Have

ID: FR-301 

* Title: User authentication and account access  
* Statement  
  * The system shall allow users to create an account, log in, and log out when entering valid credentials (username or email, and password) and restrict access to certain application features based on authentication status.  
* Rationale  
  * Authentication is required to ensure user data is protected and that the system provides personalized trip planning and collaboration between multiple users within trips.  
* Test Method:  
  * Create 10 or more user accounts that have both valid and invalid email and password combinations and verify that the system responds correctly.  
  * Verify that authenticated users can access user-specific protected pages, such as trip dashboards, with authenticated users being redirected back to login.  
  * Ensure the session state updates correctly by testing login and logout functionality.  
  * Verify that invalid credentials are rejected and met with corresponding error messages.  
* Supporting Context:  
  * Authentication will be implemented user an external service (Firebase Authentication).  
* Trace: SYS 101- Authentication and Permissions  
* Priority: Must Have

ID: FR-302

* Title: Site Tutorial  
* Statement  
  * While users register, the authentication page shall display an introductory guide to the layout and features of the site.  
* Rationale  
  * While not essential, it would be helpful to new users if we provided simple instructions to basic features such as forming groups or creating a travel plan.  
* Test Method  
  * Ensure at least 80% of users with no prior experience can create an account, log in, create a trip, invite group members, and add to an itinerary after watching the tutorial.  
* Supporting Context:  
  * N/A  
* Trace: SYS 102- Group Features  
* Priority: Could Have

ID: FR-303  

* Title: Third Party Login Support  
* Statement  
  * While users register an account, the user authentication page shall provide third party login options such as Google and Apple.  
* Rationale  
  * Today, it is standard practice to have quick sign-in options tied through Google and Apple.  
* Test Method  
  * Ensure successful Google signup and login with a valid Google Account.  
  * Ensure successful Apple signup and login with a valid Apple account.   
  * Ensure the user is redirected and the corresponding error message pops up after an intentionally invalid account creation or login attempt.  
* Supporting Context:  
  * Firebase has native support for third party login.  
* Trace: SYS 101- Authentication and Permissions  
* Priority: Could Have

ID: FR-401

* Title: Paths/Buckets for User Data and Preferences  
* Statement  
  * When a user creates an account and joins a group, the system shall store and retrieve the user's profile data and travel preferences using defined database paths associated with that user.  
* Rationale  
  * Trip planning requires storage of user preferences and group data so they can access them across different sessions. Paths provide a structured way to organize and access the data.  
* Test Method  
  * Create at least 10 user accounts and 5 test groups. Then, test creating, updating, retrieving, and deleting profile data and preferences for users.   
  * Verify that the data is stored in the correct Firebase path and loads correctly when the user returns.  
* Supporting Context:  
  * Firebase is the main backend storage system for our project, and it provides us with defined database paths to store user and group data in a structured way.  
* Trace: SYS 103- User Data Management  
* Priority: Must have

ID: FR-501

* Title: User Permission Levels  
* Statement:  
  * For planning a group trip, the system shall assign each user a role of a group organizer or group member and restrict actions. The organizers can modify trip settings and invite members, while members can only view and update their own preferences and itinerary contributions.  
* Rationale  
  * Group trips require different permission levels so that one organizer manages trips while other members contribute preferences to prevent unwanted changes to core trip settings by multiple users.  
* Test Method  
  * Create a test group trip with organizer and member accounts. Verify that organizers can edit trip settings and invite members. Then, ensure that members cannot perform these actions but can submit preferences and edit itineraries.  
  * Try to inject unauthorized actions as a member and confirm that they are blocked.  
* Supporting Context:  
  * Organizers are responsible for creating and managing the trip. Members are simply users that were invited to participate in the trip planning.  
* Trace: SYS 101- Authentication and Permissions  
* Priority: Must have

ID: FR-502

* Title: Protect Individual User Paths, Data, and Preferences  
* Statement:   
  * When a user accesses trip or preference data, the system shall restrict access so that users can only view or modify their own personal preferences and travel data.  
* Rationale  
  * User travel preferences and trip information such as flights and lodging should only be accessible to them to prevent viewing of personal data.  
* Test Method  
  * Create multiple user accounts. Verify that users can view and edit their own preferences. Then, attempt to access another user’s preferences or trip data to confirm that access is denied.  
* Supporting Context:  
  * User preferences and data include budget, flight booking information, lodging booking information, availability, and activities.  
* Trace: SYS 101-Authentication and Permissions  
* Priority: Must have

**Non-Functional Requirements**

ID: NFR-101

* Title: Minimize load times to 2 seconds between pages  
* Statement  
  * The application shall have a delay of at most 2 seconds when transitioning between pages.  
* Rationale  
  * Nothing is more irritating than when pages take significant time to load so, this is necessary to make our site feel responsive.  
* Test Method  
  * The main test method will be through stress testing the site. We will identify the main points where the most data is being rendered or transferred and if there is lag, identify ways to minimize it to under 2 seconds.  
* Supporting Context:  
  * N/A  
* Trace: SYS 102- Group Features  
* Priority Must Have

ID: NFR-102

* Title: API is refreshed every new search or when page is reloaded.  
* Statement  
  * Our APIs shall refresh every time a user performs a new search or reloads the page to ensure data is up to date.  
* Rationale  
  * The reputation of our application could be harmed if we consistently provide stale data to users.  
* Test Method  
  * Throughout development, check the prices and availability being displayed and compare to data on airline/hotel sites.  
* Supporting Context:  
  * N/A  
* Trace: SYS 105- Travel API Linking  
* Priority Must Have

ID: NFR-201 

* Title: API Rate Limit does not halt the search service  
* Statement:  
  * The system shall support travel searches without exceeding the request rate limit of 10 transactions per second per user of Amadeus API used by the application.  
* Rationale  
  * Amadeus API imposes request limits of 10 transactions per second per user so the application must manage API usage so that multiple users can search for flights, hotels, and activities without the service being interrupted.  
* Test Method  
  * Simulate travel searches by gradually increasing the number of users and monitor the API request counts and verify the number of concurrent users the system can support without exceeding the 10 transactions per second per user API rate limit.  
* Supporting Context:  
  * Travel searches send requests to Amadeus API which enforces request limits of 10 transactions per second per user.  
* Trace: SYS 105- Travel API Linking  
* Priority: Must Have

 ID: NFR-301

* Title: Site Aesthetics    
* Statement  
  * The system shall present trip planning pages with a consistent layout that allows at least 80% of the users to complete the actions such as creating trips, entering preferences, availability, and viewing itineraries. So the system shall have readable text, clearly labeled buttons, date pickers, and forms to allow users to successfully complete the above actions.  
* Rationale  
  * Users must be able to understand and navigate the interface without having to learn the layout at every single page landing so a clear visual design reduces confusion and improves usability.  
* Test Method  
  * Conduct a usability test with at least 5 test users that have not seen the application before. Verify that users can identify and use the core functions without help or confusion.  
* Supporting Context:  
  * Flutter provides built-in UI components that will help maintain layout and styling for the application’s pages.  
* Trace: SYS 102- Group Features  
* Priority: Must Have

ID: NFR-302

* Title: Multi-Page Navigation    
* Statement:  
  * The system shall provide multi-page navigation with pages for trip creation, preference input, group data, and itinerary pages.  
* Rationale  
  * Multi-page navigation helps users move between different trip planning features without confusion.  
* Test Method  
  * Navigate between the trip creation, preference input, group data, and itinerary pages using the navigation menu. Verify that each page loads correctly and navigation links appear across all pages.  
* Supporting Context:  
  * The major pages are the core functionalities of the application.  
* Trace: SYS 102- Group Features  
* Priority: Must Have

**Deliverables** 

* Production Web Application User Interface  
  * A web interface that allows users to navigate through multiple pages, create and manage trips, enter personal preferences, and view itineraries. It will include instantaneous transitions and data transfer between pages to maintain the application state.  
  * Requirements: FR-101 Multi-Page Data Transferring, NFR-301 Site Aesthetics, NFR-302 Multi-Page Navigation, NFR-101 Minimize Load Times Between Pages  
* Flight and Hotel Booking  
  * A software module that generates booking links that redirect users from the web application to the relevant booking URL. Flight and hotel links will be dynamically constructed by the module based on travel options and preferences.  
  * Requirements: FR-102 Linking to [kayak.com](http://kayak.com)  
* Retrieve flight, hotel, and activity data  
  * The system will retrieve flight, hotel, and necessary activity data. This will make sure that travel information is correctly retrieved and displayed on the web application.  
  * Requirements: FR-201 Amadeus Integration for Flight and Hotel Data, NFR-102 API is Frequently Refreshed  
* Maps Visualization  
  * A module in the itinerary page that creates a map showing travel routes, destinations, and activity locations. This will allow users to view trip routes and distances between destinations on an electronic map without leaving the web application.  
  * Requirements: FR-202 Google Maps for Itinerary Visualization  
* Authentication System  
  * Authentication system that supports account creation, login, logout, and user session management.  
  * Requirements: FR-301 Firebase Authentication Integration, FR-303 Third Party Login Support  
* User Onboarding and Tutorial Page  
  * An onboarding page that appears immediately after the user registration process to give new users an introduction to the application layout, trip creation workflow, and group features.  
  * Requirements: FR-302 Site Tutorial, NFR-301 Site Aesthetics, NFR-302 Multi-Page Navigation  
* User Permission and Access Control System  
  * A permissions management system that sets specific permission levels for users within a group trip. It will ensure that only users with correct access levels can view, edit, or manage group trip data and preferences.  
  * Requirements: FR-501 User Permission Levels, FR-502 Protect Individual User Paths, Data, and Preferences  
* Security and Malware Protection Configuration  
  * A security configuration system that protects the web application against malware and unauthorized access attempts. This will include security rules, authentication protection, and backend safeguards to protect user data and ensure overall system security.  
  * Requirements: FR-502 Protect Individual User Paths, Data, and Preferences

**Standards**

Three standards that are applicable to our team’s project are:

1. ISO/IEC 25010 – System and Software Quality Models \[1\]  
   1. Why standard is applicable:   
      1. ISO/IEC 25010 is a widely recognized model for evaluating software quality specifically in terms of reliability, usability, security, and performance efficiency. Since Syncinary will store user data and support collaborative travel planning, the quality characteristics listed in ISO/IEC 25010 provide useful guidance for designing Syncinary.  
   2. How it will impact design and code:  
      1. ISO/IEC 25010 will influence Syncinary’s design by encouraging reliable data storage, secure authentication mechanisms, and a user-friendly interface for group travel planning. It will also help guide implementation decisions like error handling and input validation while also emphasizing performance considerations that will ensure the system behaves consistently and securely.  
   3. How we’ll ensure compliance:  
      1. According to ISO/IEC 25010’s standards, compliance is supported by incorporating testing practices that evaluate reliability, usability, and security throughout development. To ensure these standards are met, we will conduct usability testing, implement basic security protections (i.e. authentication and encrypted communication), and perform system testing to ensure the application functions consistently under expected usage conditions.  
2. ISO/IEC/IEEE 29148 – Requirements Engineering \[2\]  
   1. Why standard is applicable:  
      1. ISO/IEC/IEEE 29148 provides guidance on defining, documenting, and managing system requirements. Syncinary includes multiple features such as group management, itinerary planning, and expense tracking, which all require clearly defined and traceable requirements to avoid ambiguity and scope creep.  
   2. How it will impact design and code:  
      1. This standard guides teams in how they should structure and document system requirements in SDP and other project documentation. By following this standard, it would ensure that each requirement for Syncinary is clearly defined, testable, and linked to specific system functionality.  
   3. How we’ll ensure compliance:  
      1. We will ensure compliance by documenting requirements in a structured format, maintaining traceability between requirements and implemented features, and performing periodic requirement reviews throughout the development process.  
3. OWASP Top 10 \[3\]  
   1. Why standard is applicable:  
      1. Since Syncinary is a web application handling user accounts and shared information, the application should protect itself against common security vulnerabilities.  
   2. How it will impact design and code:  
      1. According to OWASP, developers must implement secure authentication, input validation, and protection against vulnerabilities such as SQL injection and cross-site scripting. By having these guidelines in mind, Syncinary’s design and code must protect against these potential hazards.  
   3. How we’ll ensure compliance:  
      1. We will follow OWASP security guidelines, conduct security reviews during development, and test the application for known vulnerabilities.

**Development Methodology**

For our development, we will be using the Scrum methodology. This was the only methodology we all have had past exposure to and have seen most commonly used in real-world software development projects. Our plan before adapting this methodology was to create a base product and add features incrementally. This fits with the model of using sprints as each sprint can correspond to one or two features.

**Verification and Validation Plan** 

[Verification & Validation - Team 5](https://docs.google.com/document/d/1GduwFRb47rWicHX8Disco9BDMDqOVM64SX_kKsUij0Q/edit?usp=drive_link)

**Gantt Chart**

[gantt\_chart.xlsx](https://docs.google.com/spreadsheets/d/1gpyhZVvcMIDij40gbqeRMenqFHecXa_c/edit?usp=drive_link&ouid=110217928623390615024&rtpof=true&sd=true)

**Sources**

\[1\] International Organization for Standardization, “ISO/IEC 25010: Systems and software engineering — Systems and software Quality Requirements and Evaluation (SQuaRE) — System and software quality models,” 2011\. \[Online\]. Available: https://iso25000.com/index.php/en/iso-25000-standards/iso-25010

\[2\] International Organization for Standardization, International Electrotechnical Commission, and IEEE, “ISO/IEC/IEEE 29148: Systems and software engineering — Life cycle processes — Requirements engineering,” 2018\. \[Online\]. Available: https://www.iso.org/standard/72089.html

\[3\] OWASP Foundation, “OWASP Top 10: The Ten Most Critical Web Application Security Risks.” \[Online\]. Available: https://owasp.org/www-project-top-ten/  
