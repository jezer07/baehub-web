package com.zlatoapps.baehub

import android.net.Uri
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.navigation.NavController
import dev.hotwire.core.turbo.visit.VisitAction
import dev.hotwire.core.turbo.visit.VisitOptions
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.Navigator
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.HotwireBottomTab
import dev.hotwire.navigation.tabs.navigatorConfigurations

class MainActivity : HotwireActivity() {
    private data class NativeTabDefinition(
        val rootLocation: String,
        val tab: HotwireBottomTab
    )

    // Emulator: http://10.0.2.2:3000
    // Device: http://<your-lan-ip>:3000
    private val ROOT_URL = "http://10.0.2.2:3000"
    private val SIGN_IN_URL = "$ROOT_URL/users/sign_in"

    private val tabDefinitions by lazy {
        listOf(
            NativeTabDefinition(
                rootLocation = "$ROOT_URL/dashboard",
                tab = HotwireBottomTab(
                    title = "Home",
                    iconResId = android.R.drawable.ic_menu_view,
                    configuration = NavigatorConfiguration(
                        name = "home",
                        startLocation = SIGN_IN_URL,
                        navigatorHostId = R.id.nav_home_host
                    )
                )
            ),
            NativeTabDefinition(
                rootLocation = "$ROOT_URL/tasks",
                tab = HotwireBottomTab(
                    title = "Tasks",
                    iconResId = android.R.drawable.ic_menu_agenda,
                    configuration = NavigatorConfiguration(
                        name = "tasks",
                        startLocation = SIGN_IN_URL,
                        navigatorHostId = R.id.nav_tasks_host
                    )
                )
            ),
            NativeTabDefinition(
                rootLocation = "$ROOT_URL/events",
                tab = HotwireBottomTab(
                    title = "Events",
                    iconResId = android.R.drawable.ic_menu_my_calendar,
                    configuration = NavigatorConfiguration(
                        name = "events",
                        startLocation = SIGN_IN_URL,
                        navigatorHostId = R.id.nav_events_host
                    )
                )
            ),
            NativeTabDefinition(
                rootLocation = "$ROOT_URL/expenses",
                tab = HotwireBottomTab(
                    title = "Money",
                    iconResId = android.R.drawable.ic_menu_manage,
                    configuration = NavigatorConfiguration(
                        name = "money",
                        startLocation = SIGN_IN_URL,
                        navigatorHostId = R.id.nav_money_host
                    )
                )
            ),
            NativeTabDefinition(
                rootLocation = "$ROOT_URL/settings",
                tab = HotwireBottomTab(
                    title = "Settings",
                    iconResId = android.R.drawable.ic_menu_preferences,
                    configuration = NavigatorConfiguration(
                        name = "settings",
                        startLocation = SIGN_IN_URL,
                        navigatorHostId = R.id.nav_settings_host
                    )
                )
            )
        )
    }

    private lateinit var bottomNavigationController: HotwireBottomNavigationController
    private val observedNavigatorHostIds = mutableSetOf<Int>()
    private var isAuthenticated = false
    private var tabsPrimedForSession = false

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        bottomNavigationController = HotwireBottomNavigationController(
            activity = this,
            view = findViewById(R.id.bottom_navigation),
            initialVisibility = HotwireBottomNavigationController.Visibility.HIDDEN
        )
        bottomNavigationController.load(tabDefinitions.map { it.tab })
        bottomNavigationController.setOnTabSelectedListener { _, tab ->
            if (!isAuthenticated) return@setOnTabSelectedListener

            val location = delegate.findNavigatorHost(tab.configuration.navigatorHostId)
                ?.navigator
                ?.location

            if (location == null || isAuthenticationLocation(location)) {
                routeTabToRoot(tab.configuration.navigatorHostId)
            }
        }
    }

    override fun navigatorConfigurations() = tabDefinitions.map { it.tab }.navigatorConfigurations

    override fun onNavigatorReady(navigator: Navigator) {
        val hostId = navigator.host.id
        if (!observedNavigatorHostIds.add(hostId)) return

        navigator.host.navController.addOnDestinationChangedListener { controller: NavController, _, arguments ->
            val location = arguments?.getString("location") ?: return@addOnDestinationChangedListener
            updateAuthenticatedShellState(controller, location)
        }
    }

    private fun updateAuthenticatedShellState(controller: NavController, location: String) {
        if (delegate.currentNavigator?.host?.navController != controller) return

        if (isAuthenticationLocation(location)) {
            isAuthenticated = false
            tabsPrimedForSession = false
            bottomNavigationController.visibility = HotwireBottomNavigationController.Visibility.HIDDEN
            return
        }

        isAuthenticated = true
        bottomNavigationController.visibility = HotwireBottomNavigationController.Visibility.DEFAULT

        if (!tabsPrimedForSession) {
            tabsPrimedForSession = true
            primeTabsForAuthenticatedSession()
        }
    }

    private fun primeTabsForAuthenticatedSession() {
        val activeHostId = delegate.currentNavigator?.host?.id

        tabDefinitions.forEach { definition ->
            if (definition.tab.configuration.navigatorHostId == activeHostId) return@forEach
            routeTabToRoot(definition.tab.configuration.navigatorHostId)
        }
    }

    private fun routeTabToRoot(navigatorHostId: Int) {
        val definition = tabDefinitions.firstOrNull {
            it.tab.configuration.navigatorHostId == navigatorHostId
        } ?: return

        delegate.findNavigatorHost(navigatorHostId)
            ?.navigator
            ?.route(definition.rootLocation, VisitOptions(action = VisitAction.REPLACE))
    }

    private fun isAuthenticationLocation(location: String): Boolean {
        val path = Uri.parse(location).path ?: return false
        return path.startsWith("/users/sign_in") ||
            path.startsWith("/users/sign_up") ||
            path.startsWith("/users/password") ||
            path.startsWith("/users/confirmation") ||
            path.startsWith("/users/unlock")
    }
}
