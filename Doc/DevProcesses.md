Repository Architecture 
```text
Syncinary/
├── .github/
      └── workflows/ # Where the .yml files for GitHub Actions automated tests will go
            └── flutter_tests.yml
├── Doc/ # Where our project documents live
      ├── Design Document.pdf
      ├── DevProcesses.md
      └── Final SDP.md
├── proxy/ # Files relating to the API requests
      ├── node_modules/
      ├── package-lock.json
      ├── package.json
      └── server.js
├── syncinary/ # Root of our Flutter Application
      ├── android/ # Android Build
      ├── ios/ # iOS Build
      ├── lib/ # Source Files
            ├── pages/ # Individual page files for the application
            ├── theme/ # Style Sheet and Custom Widgets
            └── main.dart # Main file for project
      ├── linux/ # Linux Build
      ├── macos/ # macOS Build
      ├── test/ # Test Suite
      ├── web/ # Web Build
      ├── windows/ # Windows Build
      ├── .gitignore
      ├── .metadata
      ├── README.md
      ├── analysis_options.yaml
      ├── firebase.json
      ├── pubspec.lock
      └── pubspec.yaml
└── README.md
```
Branching  / Workflow Model 
Develop and describe the branching model your team will use.
- Branch for each feature and you can't commit directly to main.
Specify your branch naming convention.
- Named after each feature the project will develop
Clearly identify the main branches you plan to use and the purpose of each.
- We will have a branch for authentication in which we will work on user authentication.
- We will have a branch for the itinerary where all code relating to the itinerary will be pushed
- We will have a branch for the recommendation system where all code relating to our application's travel recommendations will be pushed
- We will have a branch for user groups where all code relating to user grouping will be pushed
- We will also have a branch for user profiles where users can customize their profiles.

Code Development & Review Policy 
Establish and document team policy for the use of pull requests, code reviews, and merging into common branches (integration, release, etc.).
- As of now, we will require each team member to only push to the branch of the application they are working on. If there doesn't seem to be any integration issues, we will push to the main branch.
The policy should discuss frequency, approval process, CI checks, etc
