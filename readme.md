## Overview

This project describes how to create a NodeJs application using a VsCode dev container. It showcases various techniques to improve the development experience including:

* Creating the project without having node or any other dev dependencies installed on the dev workstation.
* Debugging.
* Building and running the service using docker-compose.
* Attaching the dev container to the already running container and controlling the running process.
* Uploading the project to Github.

The requirements for this guide are:

* WSL2 installed.
* A Linux disro installed on WSL2 whose filesystem will be where the project directory lives.
* Docker Desktop installed and configured to use Linux containers.

Most Docker container base images will not have Git installed. This means that when VsCode has the project open in the dev container none of the VsCode Git integration will work. You could perform Git operations on the project from the host dev workstation WSL command line, or from a separate VsCode instance that has opened the project from its WSL directory, but that's not a pleasing experience. The most streamlined approach is to install Git in the dev container which enables the Git integration in VsCode to function as normal and that is the approach used in this guide.

## Steps to Create

### Creating the inital project

Create a project directory on your WSL2 filesystem.

Open the project directory in VsCode

Create readme.md file

Create Dockerfile

    FROM node:lts-alpine

    RUN apk add git
    
    WORKDIR /docker-node1

Add docker-compose.yml.

    version: "3.8"
    services:  
      docker-node1:
        build: ./
        tty: true
        stdin_open: true
        ports:
          - 3000:3000
          - 9229:9229
        volumes:
          - ./:/docker-node1
          - /node_modules
    
Create .devcontainer.json

    {
       "dockerComposeFile": "./docker-compose.yml",
       "service": "docker-node1",
       "workspaceFolder": "/docker-node1"
    }

Reopen the project in a VsCode dev container by running the VsCode command `Remote-Containers: Reopen in Container`

Create node project `npm init` with default options, althought I use `server.js` for the `main` entrypoint.

Install express `npm i express`

Create server.js add HelloWorld implementation

    const express = require('express')
    const app = express()
    const port = 3000
 
    app.get('/', (req, res) => {
       res.send('Hello World!')
    })
 
    app.listen(port, () => {
       console.log(`Example app listening at http://localhost:${port}`)
    })

(Optional) Add npm start script `"start": "node server.js"`

(Optional) Run `npm start` verify server can be reached at localhost:3000

Install nodemon `npm i --save-dev nodemon`

In `package.json` set the `start` script to `nodemon --inspect=0.0.0.0:9229 server.js`

Start the server, navigate to `localhost:3000` and verify the server can be reached. Modify the code and verify code changes are dynamically picked up.

### Debugging the project

In VsCode click the `Run` button on the navigation sidebar.

On the Run pane click the link `create a launch.json file`, on the `Select Environment` dropdown select the `NodeJs (preview)` launch configuration. This creates `launch.json` but adds a `launch` configuration which is not what we want. After the closing `}` of the existing configuration type a newline then press `ctrl+space`, from the list that appears, select `Node.js Attach` and press `tab` to add the new configuration. Delete the original configuration.

Add a breakpoint to the `app.get` method, on the Run page press the green `Start Debugging` button, refresh the page and verify that the breakpoint is hit.

### Enable starting the service using docker-compose.

Currently the application can be run because we manually ran `npm install` when setting up the dev constainer and then within the dev container we can run `npm start`. The following steps are necessary to enable the service to be rebuilt and run using docker-compose.

Add the following to the end of the `Dockerfile`

    COPY ["package.json", "package-lock.json", "./"]
    RUN npm install
    COPY . .

Add the following to the end of the service definition in `docker-compose.yml`

    command: npm start

To test this close the project in VsCode (or reopen in WSL). In a separate terminal run `docker ps` to verify that the dev container has exited. In a browser navigate to `localhost:3000`, it should not be reachable.

In the same separate terminal navigate to the project directory and run `docker-compose up -d --build`. This will rebuild the container from scratch, copy the `package.json` across, install all the dependencies and run the service. Once this has completed you will be able to navigate to `localhost:3000` and see the hosted application.

(Optional) With the container running it is possible to make changes to the project in VsCode opened on the WSL directory and on saving they will be recompiled and the browser reloaded. If your WSL user id is different to the root user in the dev container then VsCode will signal an error on attempting to save a modified file. This can be resolved by running `sudo chown <wsl_username> <filename>`. An better solution to the permission issue would be to run the dev container with a user having the same id as your WSL user, but there are currently issues with this approach when using bind mounted volumes. At any rate, modifying the code while the container is running via docker-compose isn't a particularly useful feature, but this demonstrates that it is nevertheless possible.

### Improve the experience connecting VsCode to an already running container

With the service run via `docker-compose up -d` opening the dev container in VsCode will cause VsCode to attach to the already running container. This is nice but the usefulness of this is limited since the terminal spawned by opening the VsCode dev container will not attach to the already running service process in the container. So if your container is already running `nodemon server.js` when you attach to it you have no way to terminate this process and execute other commands instead like `npm install` or `npm test` or the restart the server, and even if you could terminate the running server that would not be useful since that would cause the container to exit anyway, since that is the process that is keeping the container alive.

There is a solution to this that involves the use of `tmux`. `tmux` is a terminal multiplexer, which among other things enables processes to be spawned in one terminal and then attached to and controlled from another terminal.

First install `tmux` in the container by adding the following to the Dockerfile after the line which installs `git`. Note that the shell initialisation script that this creates is designed to work specifically for alpine Linux containers which use `ash` as the default shell. A different initialisation may be required for non-alpine Linux containers using `bash`. 

    # Install tmux
    RUN apk add tmux
    
    # Create a shell initialisation script that checks whether the current shell is running
    # within a tmux session, and if not attaches to an existing session.
    ENV ENV="/root/.initsh"
    RUN echo "if [ \"$TMUX\" = \"\" ]; then" > "$ENV"
    RUN echo "tmux attach -t my_session" >> "$ENV"
    RUN echo "fi" >> "$ENV"

Then replace the `command` in `docker-compose.yml` with

    command: sh -c "tmux new -d -s my_session;
      tmux send-keys -t my_session npm Space start C-m;
      tmux attach -t my_session"

Then rebuild the dev container, exit from the dev container and launch the service from a terminal using `docker-compose up -d` and verify the application is running by opening it in a browser at `localhost:3000`

Open the project dev container in VsCode. You will find the `nodemon server.js` process running in the integrated terminal in a `tmux` session. You can update the code and your changes will update in the running app, you can also exit the running `nodemon` process using `^C` and run other `npm` commands like `npm install` or `npm test` and restart the service again using `npm start`.

### Upload the project to Github

Since git is installed in the dev container the VsCode git integration will all be functional. On the VsCode navigation sidebar click the `Source Control` button and on the Source Control pane click `Initialize Repository`. VsCode provides no feedback that this has worked, but if in the terminal you execute `ls -a` you will see the `.git` directory has been created. At this point you may need to reload the window for VsCode to initialise the source control provider, you may also need to add a suitable `.gitignore` file. The node one from (here)[https://github.com/github/gitignore] is suitable.

Commit the changes to any modified files, and then in the VsCode status bar click the `Publish to Github` button. Assuming you have a Github account, you will be prompted to select either a public or provide Github repository and the project will be uploaded.

## Conclusion

This process to construct the project takes a somewhat iterative approach, adding and testing functionality a bit at a time. There is a fair amount of complexity here and building the project up in this manner and testing at each stage affords the best chance of tracking down any issues if something doesn't work. Once familiarity with the tools and configuration has been gained a project with this configuration can be more quickly constructed in one go.