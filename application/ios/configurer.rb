# NEURAVID — réglages App Store du projet iPhone (lancé par la construction, après « flutter create »).
#   ruby configurer.rb <dossier projet/ios> <dossier application/ios>
# - manifeste de confidentialité PrivacyInfo.xcprivacy dans l'application ;
# - textes des autorisations dans les 11 langues (InfoPlist.strings) ;
# - droits : domaines associés (clé d'accès et liens www.neuravid.com) ;
# - iPhone seulement (l'iPad n'est pas proposé tant que ses écrans ne sont pas faits).
require 'xcodeproj'
require 'fileutils'

ios, src = ARGV
runner = File.join(ios, 'Runner')
proj = Xcodeproj::Project.open(File.join(ios, 'Runner.xcodeproj'))
cible = proj.targets.find { |t| t.name == 'Runner' } or abort('cible Runner introuvable')
groupe = proj.main_group['Runner'] or abort('groupe Runner introuvable')

FileUtils.cp(File.join(src, 'PrivacyInfo.xcprivacy'), runner)
FileUtils.cp(File.join(src, 'Runner.entitlements'), runner)
unless groupe.files.any? { |f| f.path == 'PrivacyInfo.xcprivacy' }
  ref = groupe.new_file('PrivacyInfo.xcprivacy')
  cible.resources_build_phase.add_file_reference(ref)
end
groupe.new_file('Runner.entitlements') unless groupe.files.any? { |f| f.path == 'Runner.entitlements' }

langues = Dir.children(runner).select { |d| d.end_with?('.lproj') && File.exist?(File.join(runner, d, 'InfoPlist.strings')) }.map { |d| d.sub('.lproj', '') }.sort
abort('aucune langue') if langues.empty?
variante = groupe.children.find { |c| c.isa == 'PBXVariantGroup' && c.name == 'InfoPlist.strings' }
unless variante
  variante = groupe.new_variant_group('InfoPlist.strings')
  langues.each { |l| variante.new_file("#{l}.lproj/InfoPlist.strings").name = l }
  cible.resources_build_phase.add_file_reference(variante)
end
proj.root_object.known_regions = (proj.root_object.known_regions + langues + ['Base']).uniq

cible.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  c.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
end
proj.save
puts "Projet iPhone réglé : #{langues.size} langues, manifeste de confidentialité, domaines associés, iPhone seulement."
