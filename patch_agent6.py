with open("ios/Podfile", "r") as f:
    code = f.read()

old_post_install = """post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end"""

new_post_install = """post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end"""

if old_post_install in code:
    code = code.replace(old_post_install, new_post_install)
    with open("ios/Podfile", "w") as f:
        f.write(code)
    print("Podfile updated.")
else:
    print("Could not find post_install block.")
