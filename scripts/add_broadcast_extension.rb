#!/usr/bin/env ruby
# 在 Runner.xcodeproj 中加入 ReplayKit 屏幕共享扩展 target。
# 由 scripts/build_unsigned_ipa.sh 在构建前调用，脚本是幂等的。
require 'xcodeproj'

root = File.expand_path('..', __dir__)
project_path = File.join(root, 'ios', 'Runner.xcodeproj')
target_name = 'BroadcastUploadExtension'
extension_bundle_id = 'com.kk.remote.BroadcastUploadExtension'
app_group = 'group.com.kk.remote'

project = Xcodeproj::Project.open(project_path)
if project.targets.any? { |t| t.name == target_name }
  puts "#{target_name} 已存在，跳过"
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' }
raise '未找到 Runner target' unless runner

target = project.new_target(:app_extension, target_name, :ios, '15.0')
target.product_reference.name = target_name
target.product_reference.path = "#{target_name}.appex"
group = project.main_group.find_subpath(target_name, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(target_name)
source_ref = group.new_file('SampleHandler.swift')
target.add_file_references([source_ref])

target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = extension_bundle_id
  settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  settings['PRODUCT_MODULE_NAME'] = target_name
  settings['WRAPPER_EXTENSION'] = 'appex'
  settings['INFOPLIST_FILE'] = "#{target_name}/Info.plist"
  settings['SWIFT_VERSION'] = '5.0'
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['SKIP_INSTALL'] = 'YES'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['MARKETING_VERSION'] = '1.2.5'
  settings['CURRENT_PROJECT_VERSION'] = '41'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['LD_RUNPATH_SEARCH_PATHS'] =
    '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
end

runner.add_dependency(target)
embed_phase = runner.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' }
unless embed_phase
  embed_phase = runner.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13'
end
embed_phase.add_file_reference(target.product_reference, true)

# Xcode 要求扩展嵌入阶段位于 Flutter 的 Thin Binary 之前，
# 否则会报 "Cycle inside Runner; building could produce unreliable results"。
phases = runner.build_phases
phases.delete(embed_phase)
thin = phases.find { |p| p.display_name.to_s == 'Thin Binary' }
phases.insert(thin ? phases.index(thin) : phases.size, embed_phase)

project.save
puts "已添加 #{target_name}，App Group: #{app_group}"
