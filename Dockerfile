FROM node:lts-alpine

RUN apk add git

# Install tmux
RUN apk add tmux

# Create a shell initialisation script that checks whether the current shell is running
# within a tmux session, and if not attaches to an existing session.
ENV ENV="/root/.initsh"
RUN echo "if [ \"$TMUX\" = \"\" ]; then" > "$ENV"
RUN echo "tmux attach -t my_session" >> "$ENV"
RUN echo "fi" >> "$ENV"

WORKDIR /docker-node1

COPY ["package.json", "package-lock.json", "./"]
RUN npm install
COPY . .

