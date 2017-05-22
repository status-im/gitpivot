"""Process information from GitHubAPI"""
import sys
import os
import json
import urllib
import urllib2
from datetime import datetime
import re
 
from collections import defaultdict



startTime = datetime.now()
def logmsg(msg):
    """Logs a message into proof."""
    global startTime
    msg = str(datetime.now() - startTime)[:10] + " [GitHubOracle] "+msg+" \n"
    sys.stderr.write(msg)
logmsg(str(startTime))


class GitHubAPI:
    """Authentication and API Requests."""
    auth = 0

    def oauth(self, code):
        """Exchanges code for token."""
        req = urllib2.Request("https://github.com/login/oauth/access_token")
        req.add_header("Accept", "application/json")
        req.add_header("client_id", self.client)
        req.add_header("client_secret", self.secret)
        req.add_header("code", code)
        response = urllib2.urlopen(req)
        rjs = json.load(response)
        try:
            logmsg("OAuth success:" + rjs['scope'] + "/" + rjs['token_type'])
            return rjs['access_token']
        except KeyError:
            logmsg("OAuth error " + rjs['error'] + ":" + rjs['error_description'])
            logmsg(rjs['error_uri'])
            sys.exit("403 Forbidden")

    def __init__(self, auth):
        autharg = [x.strip() for x in auth.split(',')]
        if len(autharg) == 3: #is token
            logmsg("Using OAuth")
            self.client = autharg[0]
            self.secret = autharg[1]
            self.token = self.oauth(autharg[2])
            self.auth = 2
        elif len(autharg) == 2: #is secret
            logmsg("Using Secret Mode")
            self.client = autharg[0]
            self.secret = autharg[1]
            self.auth = 1
        elif len(autharg) == 1 and len(autharg[0]) > 0:
            logmsg("Using Token")
            self.token = autharg[0]
            self.auth = 2
        else:
            logmsg("Anonymous API")
            self.auth = 0
        api_link = "https://api.github.com/rate_limit"
        if self.auth == 1:
            req = urllib2.Request(api_link+"?client_id="+self.client+"&client_secret="+self.secret)
        elif self.auth == 2:
            req = urllib2.Request(api_link)
            req.add_header("Access-Token", self.token)
        else:
            req = urllib2.Request(api_link)
        res = json.load(urllib2.urlopen(req))
        self.api = defaultdict(int)
        self.api['rate_limit'] = int(res['rate']['limit'])
        self.api['rate_remaining'] = int(res['rate']['remaining'])
        self.api['rate_reset'] = int(res['rate']['reset'])
        logmsg("API calls remaining: "+ str(self.api['rate_remaining']))

    def check_limit(self, more_than=0):
        """Returns True if under limit, else log and return False."""
        if self.api['rate_remaining'] > more_than:
            return True
        else:
            logmsg("X-RateLimit reached. Try again in "+self.api['rate_reset']+".")
            return False

    def request(self, api_link, arguments_get=None, arguments_post=None, headers=None):
        """Request something to API using authentication."""
        if arguments_get is None:
            arguments_get = []
        if self.auth == 1:
            arguments_get += [["client_id", self.client], ["client_secret", self.secret]]
        if self.auth == 2:
            headers += [["Access-Token", self.token]]
        if len(arguments_get) > 0:
            api_link += "?"
            for argument in arguments_get:
                api_link += argument[0]+"="+argument[1]+"&"
            api_link = api_link[0:-1]
        req = urllib2.Request(api_link)
        if headers is not None and len(headers) > 0:
            for header in headers:
                req.add_header(header[0], header[1])
        if arguments_post is None:
            response = urllib2.urlopen(req)
        else:
            response = urllib2.urlopen(req, urllib.urlencode(arguments_post))
        self.api['rate_limit'] = int(response.headers.get("X-RateLimit-Limit"))
        self.api['rate_remaining'] = int(response.headers.get("X-RateLimit-Remaining"))
        self.api['rate_reset'] = int(response.headers.get("X-RateLimit-Reset"))
        return response

class GitRepository:
    """Uses API to load Repository Data"""
    branch = None
    head = ""
    tail = ""
    repo_link = ""
    points = defaultdict(int)
    config = defaultdict(str)
    count = 0
    api = None

    def __init__(self, api, repository, branch=None, name=True):
        self.api = api
        if name:
            self.repo_link = "https://api.github.com/repos/"
        else:
            self.repo_link = "https://api.github.com/repositories/"
        self.repo_link += repository
        self.data = json.load(api.request(self.repo_link))
        if branch != None:
            self.branch_name = branch
        else:    
            self.branch_name = self.data['default_branch']
        self._load_config()
        if self.config['user-agent'] != '*' and self.config['user-agent'] != 'githuboracle':
            print 'ignored exit' #sys.exit("403 Forbidden")
            self.config['reward-mode'] = "words"

    def _load_config(self):    
        config_file = "https://raw.githubusercontent.com/"+self.data['full_name']+"/"+self.branch_name+"/.gitrobots"
        req = urllib2.Request(config_file)
        try:
            response = urllib2.urlopen(req).read().lower()
            for line in response.splitlines():
                logmsg("Rule loaded "+line)
                param = line.split(':')
                self.config[param[0].strip()] = param[1].strip()
        except urllib2.HTTPError:
            logmsg("No .gitrobots in branch root")

    def set_branch(self, branch_name):
        """Sets the working branch."""
        self.branch = None
        self.branch_name = branch_name

    def set_head(self, head):
        """Set the latest head."""
        self.head = head

    def set_tail(self, tail):
        """Set the further tail"""
        self.tail = tail

    def get_branch(self):
        """Get branch data."""
        logmsg("Loaded branch " + self.branch_name)
        if self.branch is None:
            branches_link = self.repo_link + "/branches/" + self.branch_name
            self.branch = json.load(self.api.request(branches_link))
        return self.branch

    def __parse_link_header(self, headers):
        links = {}
        if "Link" in headers:
            link_headers = headers["Link"].split(", ")
            for link_header in link_headers:
                (url, rel) = link_header.split("; ")
                url = url[1:-1]
                rel = rel[5:-1]
                links[rel] = url
        return links

    def update_commits(self):
        branch_head = self.get_branch()['commit']['sha']
        logmsg("Loading from "+branch_head+ (" up to "+self.head if len(self.head) > 0 else "") + ".")
        page = '1'
        while self.api.check_limit():
            response = self.api.request(self.repo_link + "/commits", [['per_page', '100'], ['sha', branch_head], ['page', page]])
            commits = json.load(response)
            logmsg("page "+page+" contains " + str(len(commits)) +" commits.")
            for commit in commits:
                if commit['sha'] != self.head:
                    author = commit['author']['id']
                    if self.api.check_limit() and not (len(self.points) > 10 and self.points[author] == 0):
                        self.tail = self.__claim_commit(commit)['sha']
                    else:
                        self.head = branch_head
                        return self.tail
                else:
                    logmsg(commit['sha']+": <last claimed commit>")
                    self.tail = commit['sha']
                    self.head = branch_head
                    return self.tail
            try:
                links = self.__parse_link_header(response.headers)
                page = links['next'].split('&page=')[1].split('&')[0]
            except KeyError:
                logmsg("Reached end of pagination.")
                break
        self.head = branch_head
        return self.tail

    def continue_loading(self, old_tail, limit=""):
        logmsg("Continuing from "+old_tail+ (" up to "+limit if len(limit) > 0 else "") +".")
        page = '1'
        claim = False
        while self.api.check_limit():
            response = self.api.request(self.repo_link + "/commits", [['per_page', '100'], ['sha', self.head], ['page', page]])
            commits = json.load(response)
            logmsg("page "+page+" contains " + str(len(commits)) +" commits.")
            for commit in commits:
                if commit['sha'] != limit:
                    if commit['sha'] == old_tail:
                        logmsg(commit['sha']+": <found old tail>")
                        claim = True
                    elif claim:
                        author = commit['author']['id']
                        if self.api.check_limit() and not (len(self.points) > 10 and self.points[author] == 0):
                            self.tail = self.__claim_commit(commit)['sha']
                        else:
                            return self.tail
                else:
                    logmsg(commit['sha']+": <last claimed commit>")
                    self.tail = limit
                    return self.tail
            try:
                links = self.__parse_link_header(response.headers)
                page = links['next'].split('&page=')[1].split('&')[0]
            except KeyError:
                logmsg("Reached end of pagination.")
                break
        return self.tail

    def __claim_commit(self, commit):
        self.count += 1
        if len(commit['parents']) < 2 and commit['author'] is not None:
            commit = json.load(self.api.request(commit['url']))
            self.compute_points(commit)
        else:
            if len(commit['parents']) >= 2:
                parents = ""
                for parent in commit['parents']:
                    parents += parent['sha']+", "
                logmsg(commit['sha'] +": <merge: " + parents[:-2] + ">")
            elif commit['author'] is None:
                logmsg(commit['sha'] +": <unknown author>")
            else:
                logmsg(commit['sha'] +": <already claimed>")
        return commit

    def issue_points(self, issueid):
        link_issue = self.repo_link + "/issues/" + issueid
        aissue = json.load(self.api.request(link_issue))
        link_issue = self.repo_link + "/issues/" + issueid + "/timeline"
        issue_timeline = json.load(self.api.request(link_issue, None, None, [["Accept", "application/vnd.github.mockingbird-preview"]]))
        for elem in issue_timeline:
            if elem["event"] == "cross-referenced":
                if elem["source"]["type"] == "issue":
                    refissue = str(elem["source"]["issue"]["number"])
                    try:
                        self.pull_points(refissue)
                    except urllib2.HTTPError:
                        logmsg("Found cross-referenced issue #"+refissue)
        return aissue
        
    def pull_points(self, pullid):
        link_pull = self.repo_link + "/pulls/" + pullid
        pull = json.load(self.api.request(link_pull))
        if pull['merged_at']:
            logmsg("Found cross-referenced pull #"+pullid+" merged at "+ pull['merged_at'])
            link_pulls_commits = self.repo_link + "/pulls/" + pullid + "/commits"
            commits = json.load(self.api.request(link_pulls_commits))
            for commit in commits:
                if commit['url']:
                    _commit = json.load(self.api.request(commit['url']))
                    self.compute_points(_commit)

    def compute_points(self, _commit):
        author = _commit['author']['id']
        points = 0
        rewards = self.config['reward-mode'].split(',')
        for reward in rewards:
            if reward == 'lines':
                points += int(_commit['stats']['additions'])
            elif reward == "words":
                points += self._compute_words(_commit)
        if points > 0:
            self.points[author] += points
        logmsg(_commit['sha']+": "+  _commit['author']['login'] + " +" + str(points))

    def _compute_words(self, _commit):
        pattern = re.compile('[\W_]+')
        points = 0
        for _file in _commit['files']:
            if _file['additions'] > 0:
                try:
                    for line in _file['patch'].splitlines():
                        if line[0] == '+':
                            points += len(filter(None, pattern.sub(' ', line).split(' ')))
                except KeyError:
                    if self.config['compute-bigfiles'] == "yes" and _file['status'] == 'added':
                        req = urllib2.Request(_file['raw_url'])
                        response = urllib2.urlopen(req).read()
                        for line in response.splitlines():
                            points += len(filter(None, pattern.sub(' ', line).split(' ')))
                    else:
                        logmsg(_commit['sha']+": " + _file['sha'] + " file too big")
        return points

#Script start
try:    
    argn = int(os.environ['ARGN'])
except KeyError:
    sys.exit("400 Error") #bad call

try:
    script = os.environ['ARG0']
    args = os.environ['ARG1']
except KeyError:
    sys.exit("404 Error") #bad call

try:
    api_auth = os.environ['ARG2']
except KeyError:
    api_auth = ""

try:
    settings = os.environ['ARG3']
except KeyError:
    settings = ""

out = ""
logmsg("Started '" + script + " "+ args)
myApi = GitHubAPI(api_auth)
args = [x.strip() for x in args.split(',')]
try:
    branch = args[1];
except KeyError:
    branch = None
if myApi.check_limit(5):
    repository = GitRepository(myApi, args[0], branch)
    if script == 'update':
        repository.set_branch(args[1])
        repository.set_head(args[2])
        repository.update_commits()
        out += "["+json.dumps(repository.data['id'])+"," + json.dumps(repository.branch['name']) + ","
        out += json.dumps(repository.head) + "," + json.dumps(repository.tail) + ","
        out += str(len(repository.points)) + ","
        out += json.dumps(repository.points.items())
        out += "]"
    elif script == 'start':
        repository.set_branch(args[1])
        repository.update_commits()
        out += "["+json.dumps(repository.data['id'])+"," + json.dumps(repository.branch['name']) + ","
        out += json.dumps(repository.head) + "," + json.dumps(repository.tail) + ","
        out += str(len(repository.points)) + ","
        out += json.dumps(repository.points.items())
        out += "]"
    elif script == 'rtail':
        repository.set_branch(args[1])
        newTail = repository.continue_loading(args[2])
        out += "["+json.dumps(repository.data['id'])+"," + json.dumps(repository.get_branch()['name']) + ","
        out += json.dumps(newTail) + ","
        out += str(len(repository.points)) + ","
        out += json.dumps(repository.points.items())
        out += "]"
    elif script == 'resume':
        repository.set_branch(args[1])
        newTail = repository.continue_loading(args[2],args[3])
        out += "["+json.dumps(repository.data['id'])+"," + json.dumps(repository.get_branch()['name']) + ","
        out += json.dumps(newTail) + ","
        out += str(len(repository.points)) + ","
        out += json.dumps(repository.points.items())
        out += "]"
    elif script == "issue":
        issueid = args[1];
        issue = repository.issue_points(issueid)
        try:
            closed_at = datetime.strptime(issue['closed_at'], "%Y-%m-%dT%H:%M:%SZ").strftime('%s');
        except TypeError:
            closed_at = "0"
        out += "["+json.dumps(repository.data['id'])+", " + issueid+", "
        out += json.dumps(issue['state']) + ", " + closed_at + ", "
        out += str(len(repository.points)) + ", "
        out += json.dumps(repository.points.items())
        out += "]"
    else:
        sys.exit("501 Not implemented")
else:
    sys.exit("503 Service Unavailable")


print out;