path = require 'path'

normalizePath = (pathToNormalize) ->
  normPath = path.normalize pathToNormalize
  if process.platform is 'darwin'
    # For some reason the paths returned by the tree-view and
    # git-utils are sometimes "different" on Darwin platforms.
    # E.g. /private/var/... (real path) !== /var/... (symlink)
    # For now just strip away the /private part.
    # Using the fs.realPath function to avoid this issue isn't such a good
    # idea because it tries to access that path and in case it's not
    # existing path an error gets thrown + it's slow due to fs access.
    normPath = normPath.replace(/^\/private/, '')
  return normPath.replace(/[\\\/]$/, '')

allPathSegments = (pathToSegment) ->
  pathSegments = []
  if pathToSegment.includes('/')
    splitChar = '/'
  else
    splitChar = '\\'
  pathParts = normalizePath(pathToSegment).split(splitChar)
  upperLimit = pathParts.length
  [1..upperLimit].forEach (i) ->
    pathToAdd = pathParts.slice(0,i).join(splitChar)
    if pathToAdd.endsWith(':')
      pathToAdd += splitChar
    if not pathSegments.includes(pathToAdd)
      pathSegments.push(pathToAdd)
  return pathSegments

module.exports = {
  normalizePath: normalizePath,
  allPathSegments: allPathSegments
}
