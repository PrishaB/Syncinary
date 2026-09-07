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
- The main branch will be locked from direct commits. Branches will be made for new features. Branches can be made off of other branches for the purpose of testing new sub features. 
Specify your branch naming convention.
- Named after each feature the project will develop and the sub feature in the format MAINFEATURE_SUBFEATURE. For example, adding a login page would be the branch auth_login.
Clearly identify the main branches you plan to use and the purpose of each.
- We will have a branch for authentication in which we will work on user authentication.
- We will have a branch for the itinerary where all code relating to the itinerary will be pushed
- We will have a branch for the recommendation system where all code relating to our application's travel recommendations will be pushed
- We will have a branch for user groups where all code relating to user grouping will be pushed
- We will also have a branch for user profiles where users can customize their profiles.
- We will have a branch for the development of LLM systems in our project.

Code Development & Review Policy 
Establish and document team policy for the use of pull requests, code reviews, and merging into common branches (integration, release, etc.).
In order for code to be pushed to main, two things are required: 
- First, there must be a full code review by at least one team member who did not contribute to that branch. The reviewer should leave comments. These comments must be addressed by the User creating the PR before it can be integrated into the main branch.
- Second, the code must pass all of the test cases currently in the repository and run automatically by GitHub Actions. If there is a case where a test fails and the User believes the test itself needs to change then, it will be a team discussion.
Every two weeks, there will be a Sprint Review where the PRs from the past two weeks will be reviewed a second time.

Pull Requests should be given a short title summarizing the bulk of the changes. The description should have finer details on changes made. Issues resolved should be noted at the bottom of the request in the form "Closes #ISSUE_ID"

Closing Out 2-week Chunk of Work

At the end of the 2-weeks chunk of work, our team will have a review and planning meeting. During the meeting, the team will collectively review the completed issues and confirm that the completion meets the criteria we discussed at the beginning. We will close those completed issues and update their status in the GitHub Project. Then, we will review the unfinished issues and discuss what were the blockers and how we should proceed on completing that. The unfinished issues may be broken into smaller tasks or taken up by someone else more experienced in completing the issue.

Refreshing Our Views

We will review update the roadmap and the 2-weeks view at the end of the 2-week cycle meeting. The second half of the meeting will focus on planning the issues we want to prioritize for the next 2 weeks. We will check that all the dependencies or blockers for those issues have been resolved to ensure that doesn't set us back. Finally, we will ensure that the roadmap reflects the team's current development priorities and there were no changes we made to our sdp.
