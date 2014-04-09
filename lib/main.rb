## gem1.9.1 install rubytree

require_relative 'util/site_builder'
siteBuilder = SiteBuilder.new('/home/saheba-universalHome/work/puppetmasterGitRepo/manifests')
siteBuilder.buildEffectiveSitePP
puts siteBuilder
